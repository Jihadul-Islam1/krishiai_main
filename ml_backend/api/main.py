"""FastAPI inference server for Krishi AI's online crop disease models.

The app diagnoses rice on-device; potato, tomato, eggplant and maize photos
are sent here so their models don't bloat the APK.

Endpoints
---------
GET  /health   — liveness + which crops have a model on disk (cheap, no TF).
POST /predict  — multipart `crop` (potato | tomato | eggplant | maize | rice)
                 + `file` (image). Returns top-K labels and the model's verdict.

Model layout — one folder per crop:
    models/<crop>/model.tflite    preferred (small, fast)   or  model.keras
    models/<crop>/labels.txt      one label per line, in model output order
    models/<crop>/meta.json       optional, e.g. the notebook's *_model_meta.json:
                                  {"classes_bn": [...], "confident_threshold": 0.5,
                                   "min_threshold": 0.4, "model": "mobilenetv3large"}

Labels must match the keys in the app's lib/data/library/<crop>_disease_info.dart
("late_blight", "healthy", ...); add a "not_leaf" class to reject photos that
aren't a leaf of that crop.

Models take float32 RGB in 0–255 (preprocessing lives inside the model, as in
ml/rice_disease_training.ipynb) at the size of their input layer.

Run:
    uvicorn ml_backend.api.main:app --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import io
import json
import logging
import os
import threading
import time
from pathlib import Path

import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, Field

try:
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parents[1] / ".env")
except Exception:
    pass

LOG = logging.getLogger("krishi-api")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

CROPS = ("potato", "tomato", "eggplant", "maize", "rice")
MODELS_DIR = Path(os.getenv("MODELS_DIR", str(Path(__file__).resolve().parents[1] / "models")))
TOP_K = int(os.getenv("TOP_K", "3"))
DEFAULT_CONFIDENT = float(os.getenv("CONF_THRESHOLD", "0.5"))
DEFAULT_MIN = float(os.getenv("MIN_THRESHOLD", "0.4"))


# ---------------------------------------------------------------------------
# Schemas (mirrored by lib/core/network/disease_api_service.dart)
# ---------------------------------------------------------------------------


class Prediction(BaseModel):
    label: str                # "late_blight" — key into the app's advisory map
    label_bn: str             # "নাবী ধসা রোগ", from meta.json classes_bn
    label_en: str
    confidence: float         # 0.0 – 1.0
    severity: str = "medium"  # the app uses its own severity when it knows the label


class PredictResponse(BaseModel):
    crop: str
    model_version: str
    inference_ms: int
    top_k: list[Prediction]
    is_confident: bool        # top-1 >= the model's confident_threshold
    probable: bool            # top-1 >= min_threshold (worth showing as "সম্ভাব্য")
    advisory: dict = Field(default_factory=dict)
    note_bn: str


class HealthResponse(BaseModel):
    status: str
    uptime_s: float
    crops: dict[str, bool]    # crop -> model files present


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------


def _tflite_interpreter(path: Path):
    # LiteRT is the small runtime the deployed server installs (no TensorFlow,
    # fits a 512 MB instance); a dev machine with TensorFlow works too.
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        import tensorflow as tf

        Interpreter = tf.lite.Interpreter
    return Interpreter(model_path=str(path), num_threads=os.cpu_count())


def _resize_bilinear(image: np.ndarray, size: int) -> np.ndarray:
    """`tf.image.resize(image, (size, size), "bilinear")` in numpy.

    Half-pixel centres, no antialiasing — what the training notebooks used.
    Rows and columns are picked before converting to float, so a large photo
    never becomes a full-size float array.
    """

    def taps(n_in: int):
        x = (np.arange(size, dtype=np.float32) + 0.5) * np.float32(n_in / size) - 0.5
        lo = np.floor(x)
        return (
            np.clip(lo, 0, n_in - 1).astype(np.intp),
            np.clip(np.ceil(x), 0, n_in - 1).astype(np.intp),
            x - lo,
        )

    y0, y1, fy = taps(image.shape[0])
    x0, x1, fx = taps(image.shape[1])

    def across(rows: np.ndarray) -> np.ndarray:
        left = rows[:, x0].astype(np.float32)
        return left + (rows[:, x1].astype(np.float32) - left) * fx[None, :, None]

    top, bottom = across(image[y0]), across(image[y1])
    return top + (bottom - top) * fy[:, None, None]


class CropModel:
    """One crop's classifier, loaded once and shared by requests."""

    def __init__(self, crop: str, folder: Path) -> None:
        self.crop = crop
        self.labels = [
            line.strip()
            for line in (folder / "labels.txt").read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        meta_path = folder / "meta.json"
        meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
        names_bn = meta.get("classes_bn") or []
        self.names_bn = names_bn if len(names_bn) == len(self.labels) else self.labels
        self.confident = float(meta.get("confident_threshold", DEFAULT_CONFIDENT))
        self.minimum = float(meta.get("min_threshold", DEFAULT_MIN))
        self.version = str(meta.get("model_version") or f"{crop}-{meta.get('model', 'model')}")

        self._lock = threading.Lock()
        tflite_path = folder / "model.tflite"
        if tflite_path.exists():
            self._interp = _tflite_interpreter(tflite_path)
            self._interp.allocate_tensors()
            inp = self._interp.get_input_details()[0]
            out = self._interp.get_output_details()[0]
            self._in_index, self._out_index = inp["index"], out["index"]
            self.size = int(inp["shape"][1])
            n_out = int(out["shape"][-1])
            self._keras = None
        else:
            import tensorflow as tf  # heavy; only for a model.keras without a .tflite

            self._interp = None
            self._keras = tf.keras.models.load_model(folder / "model.keras", compile=False)
            self.size = int(self._keras.input_shape[1])
            n_out = int(self._keras.output_shape[-1])

        if n_out != len(self.labels):
            raise ValueError(
                f"{crop}: model has {n_out} outputs but labels.txt has {len(self.labels)} labels"
            )
        LOG.info("%s model ready: %d classes, %dpx, v=%s", crop, n_out, self.size, self.version)

    def predict(self, image: Image.Image) -> np.ndarray:
        # Same bilinear resize as training (tf.image.resize), values stay 0–255.
        arr = _resize_bilinear(np.asarray(image), self.size)[None, ...]
        if self._interp is not None:
            with self._lock:  # a TFLite interpreter isn't thread-safe
                self._interp.set_tensor(self._in_index, arr)
                self._interp.invoke()
                return self._interp.get_tensor(self._out_index)[0].copy()
        return self._keras.predict(arr, verbose=0)[0]


_MODELS: dict[str, CropModel] = {}
_LOAD_LOCK = threading.Lock()


def _folder(crop: str) -> Path:
    return MODELS_DIR / crop


def _available(crop: str) -> bool:
    folder = _folder(crop)
    has_model = (folder / "model.tflite").exists() or (folder / "model.keras").exists()
    return has_model and (folder / "labels.txt").exists()


def _get_model(crop: str) -> CropModel:
    model = _MODELS.get(crop)
    if model is None:
        with _LOAD_LOCK:
            model = _MODELS.get(crop)
            if model is None:
                LOG.info("loading %s model from %s", crop, _folder(crop))
                model = _MODELS[crop] = CropModel(crop, _folder(crop))
    return model


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Krishi AI — Disease Inference API",
    version="2.0.0",
    description="Per-crop leaf disease classifiers. Returns top-K labels with the model's verdict.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

_START_TS = time.time()


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        uptime_s=round(time.time() - _START_TS, 2),
        crops={crop: _available(crop) for crop in CROPS},
    )


@app.post("/predict", response_model=PredictResponse)
async def predict(crop: str = Form(...), file: UploadFile = File(...)) -> PredictResponse:
    crop = crop.strip().lower()
    if crop not in CROPS:
        raise HTTPException(status_code=400, detail=f"unknown crop '{crop}', expected one of {CROPS}")
    if not _available(crop):
        # The app shows "model not ready yet" for 503.
        raise HTTPException(status_code=503, detail=f"model for crop '{crop}' is not available")

    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="empty upload")
    try:
        # Phone photos carry their rotation in EXIF.
        image = ImageOps.exif_transpose(Image.open(io.BytesIO(raw))).convert("RGB")
    except (UnidentifiedImageError, OSError) as e:
        raise HTTPException(status_code=400, detail="file is not a readable image") from e

    try:
        model = await run_in_threadpool(_get_model, crop)
    except Exception as e:
        LOG.exception("failed to load %s model", crop)
        raise HTTPException(status_code=503, detail=f"model for crop '{crop}' failed to load") from e

    t0 = time.time()
    probs = await run_in_threadpool(model.predict, image)
    top_idx = np.argsort(probs)[::-1][:TOP_K]
    top_k = [
        Prediction(
            label=model.labels[i],
            label_bn=model.names_bn[i],
            label_en=model.labels[i].replace("_", " ").title(),
            confidence=round(float(probs[i]), 4),
        )
        for i in (int(j) for j in top_idx)
    ]

    top1 = top_k[0].confidence
    is_confident = top1 >= model.confident
    probable = top1 >= model.minimum
    note_bn = (
        "এটি এআই-এর প্রাথমিক পরামর্শ, চূড়ান্ত রোগ নির্ণয় নয়। "
        "সঠিক নির্ণয় ও ব্যবস্থাপনার জন্য স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন।"
        if is_confident
        else "এআই মডেল যথেষ্ট নিশ্চিত নয়। পরিষ্কার ছবি তুলে আবার চেষ্টা করুন "
        "অথবা বিশেষজ্ঞের পরামর্শ নিন।"
    )

    return PredictResponse(
        crop=crop,
        model_version=model.version,
        inference_ms=int((time.time() - t0) * 1000),
        top_k=top_k,
        is_confident=is_confident,
        probable=probable,
        note_bn=note_bn,
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "ml_backend.api.main:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000")),
    )
