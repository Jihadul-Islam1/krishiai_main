"""FastAPI inference server for Krishi AI's rice disease model.

Endpoints
---------
GET  /health       — liveness probe + whether the model is loaded.
GET  /model-info   — exposes label space, image size, threshold.
POST /predict      — accepts a multipart `file` (image), returns
                     top-K predictions with Bangla advice.

Run:
    uvicorn ml_backend.api.main:app --host 0.0.0.0 --port 8000 --reload

The Flutter app's `DiseaseApiService` talks to this server. When the
backend is unreachable, the Flutter side falls back to its existing
library-only mock so the demo never breaks.
"""

from __future__ import annotations

import io
import json
import logging
import os
import time
from pathlib import Path

import numpy as np
from PIL import Image
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parents[1] / ".env")
except Exception:
    pass

from ml_backend.api.advisories import get as get_advisory

LOG = logging.getLogger("krishi-api")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# Lazy-loaded globals — see `_ensure_loaded`.
_MODEL = None
_LABELS: list[str] = []
_LABEL_EN: dict[str, str] = {}
_IMG_SIZE: int = 224
_THRESHOLD: float = 0.60
_TOP_K: int = 3


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class Prediction(BaseModel):
    label: str                # "rice_blast"
    label_bn: str             # "ধানের ব্লাস্ট"
    label_en: str             # "Rice Blast"
    confidence: float         # 0.0 – 1.0
    severity: str             # low | medium | high


class PredictResponse(BaseModel):
    model_version: str
    inference_ms: int
    top_k: list[Prediction]
    is_confident: bool        # True if top-1 >= threshold
    probable: bool            # True if top-1 >= 0.30 (still worth showing)
    advisory: dict            # Bangla advice for top-1 label
    note_bn: str              # Disclaimer appended as Bangla text


class ModelInfo(BaseModel):
    loaded: bool
    labels: list[str]
    label_en: dict[str, str]
    img_size: int
    threshold: float
    top_k: int


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    uptime_s: float


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Krishi AI — Disease Inference API",
    version="1.0.0",
    description="Rice leaf disease classifier. Returns top-K predictions with Bangla advisory.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

_START_TS = time.time()


def _ensure_loaded() -> None:
    """Lazy-load the trained model and labels file."""
    global _MODEL, _LABELS, _LABEL_EN, _IMG_SIZE, _THRESHOLD, _TOP_K
    if _MODEL is not None:
        return

    import tensorflow as tf  # heavy import

    model_path = Path(os.getenv("MODEL_PATH", "models/rice_disease_mobilenetv2.h5"))
    labels_path = Path(os.getenv("LABELS_PATH", "models/labels.json"))

    _IMG_SIZE = int(os.getenv("IMG_SIZE", "224"))
    _THRESHOLD = float(os.getenv("CONF_THRESHOLD", "0.60"))
    _TOP_K = int(os.getenv("TOP_K", "3"))

    if not model_path.exists() or not labels_path.exists():
        LOG.warning(
            "model artefacts missing (%s, %s); running in HEAL_LIGHTWEIGHT mode",
            model_path,
            labels_path,
        )
        _LABELS = [
            "rice_healthy",
            "rice_blast",
            "rice_brown_spot",
            "rice_bacterial_leaf_blight",
            "rice_tungro",
            "rice_sheath_blight",
        ]
        _LABEL_EN = {k: k for k in _LABELS}
        return

    LOG.info("loading model from %s", model_path)
    _MODEL = tf.keras.models.load_model(model_path)
    with labels_path.open(encoding="utf-8") as fh:
        meta = json.load(fh)
    _LABELS = meta["labels"]
    _LABEL_EN = meta.get("label_en", {k: k for k in _LABELS})
    _IMG_SIZE = meta.get("img_size", _IMG_SIZE)
    LOG.info("model ready: %d classes, img_size=%d", len(_LABELS), _IMG_SIZE)


def _preprocess(raw: bytes) -> np.ndarray:
    """Decode upload bytes to a (1, H, W, 3) float32 tensor."""
    img = Image.open(io.BytesIO(raw)).convert("RGB").resize((_IMG_SIZE, _IMG_SIZE))
    arr = np.asarray(img, dtype=np.float32)
    arr = np.expand_dims(arr, axis=0)
    # MobileNetV2 expects [-1, 1] inputs; tf.keras.applications.mobilenet_v2
    # ships the matching `preprocess_input` we use in the trainer.
    import tensorflow as tf
    from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
    arr = preprocess_input(arr)
    return arr


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    _ensure_loaded()
    return HealthResponse(
        status="ok",
        model_loaded=_MODEL is not None,
        uptime_s=round(time.time() - _START_TS, 2),
    )


@app.get("/model-info", response_model=ModelInfo)
def model_info() -> ModelInfo:
    _ensure_loaded()
    return ModelInfo(
        loaded=_MODEL is not None,
        labels=_LABELS,
        label_en=_LABEL_EN,
        img_size=_IMG_SIZE,
        threshold=_THRESHOLD,
        top_k=_TOP_K,
    )


@app.post("/predict", response_model=PredictResponse)
async def predict(file: UploadFile = File(...)) -> PredictResponse:
    _ensure_loaded()
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="empty upload")

    t0 = time.time()
    arr = _preprocess(raw)

    if _MODEL is None:
        # Lightweight fallback so the endpoint never 500s — useful when the
        # user hasn't run the trainer yet. The probabilities are uniform so
        # the Flutter UI still shows "uncertain / needs expert review".
        probs = np.full(len(_LABELS), 1.0 / len(_LABELS), dtype=np.float32)
    else:
        probs = _MODEL.predict(arr, verbose=0)[0]

    top_idx = probs.argsort()[::-1][: _TOP_K]
    top_k = []
    for i in top_idx:
        key = _LABELS[int(i)]
        adv = get_advisory(key)
        top_k.append(
            Prediction(
                label=key,
                label_bn=adv["name_bn"],
                label_en=adv.get("name_en") or _LABEL_EN.get(key, key),
                confidence=float(round(probs[int(i)], 4)),
                severity=adv["severity"],
            )
        )

    top1_conf = top_k[0].confidence if top_k else 0.0
    is_confident = top1_conf >= _THRESHOLD
    probable = top1_conf >= 0.30

    advisory = get_advisory(top_k[0].label) if top_k else get_advisory("rice_healthy")

    note_bn = (
        "এটি একটি সম্ভাব্য রোগ নির্ণয় (AI প্রাথমিক পরামর্শ), চূড়ান্ত নিশ্চিত নয়। "
        "সঠিক নির্ণয় ও ব্যবস্�াপনার জন্য স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন।"
        if is_confident
        else "AI মডেল যথেষ্ট নিশ্�িত নয়। পরিষ্কার ছবি তুলে আবার চেষ্টা করুন অথবা বিশে�জ্ঞের পরামর্শ নিন।"
    )

    return PredictResponse(
        model_version="rice-mobilenetv2-1.0",
        inference_ms=int((time.time() - t0) * 1000),
        top_k=top_k,
        is_confident=is_confident,
        probable=probable,
        advisory=advisory,
        note_bn=note_bn,
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "ml_backend.api.main:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000")),
        reload=True,
    )