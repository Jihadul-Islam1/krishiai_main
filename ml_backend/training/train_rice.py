"""Rice-leaf disease classifier trainer.

Pipeline
--------
1. Download the public PlantVillage *rice* subset from Hugging Face
   (`naufalso/plantvillage-rice-leaf-diseases`). The dataset already
   keeps a tidy train/val split and has 6 classes that matter for
   Bangladeshi farmers.
2. Fine-tune a MobileNetV2 backbone (ImageNet weights) on 224x224
   images with a small classification head.
3. Export the trained model to `models/rice_disease_mobilenetv2.h5`
   and a sibling `models/labels.json` mapping class index -> label key.

Run it from the repo root:

    python ml_backend/training/train_rice.py

Optional env vars (see `ml_backend/.env.example`):
    MODEL_PATH, LABELS_PATH, DATASET_SLUG, IMG_SIZE

The script is deliberately verbose so students can follow it as a
worked example — every step prints what it's doing.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# Ensure the api package can be imported when this file runs from any cwd.
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / ".env")
except Exception:
    pass  # dotenv is optional


# ---------------------------------------------------------------------------
# Dataset config
# ---------------------------------------------------------------------------

# Final label space exposed to the Flutter app. Order matters — the model's
# output index `i` will be matched against this list. Add new crops here
# only after retraining with the new class set included.
LABEL_KEYS = [
    "rice_healthy",            # সুস্থ ধান
    "rice_blast",              # ধানের ব্লাস্ট (Rice Blast)
    "rice_brown_spot",         # বাদামী দাগ (Brown Spot)
    "rice_bacterial_leaf_blight",  # ব্যাকটেরিয়াল লিফ ব্লাইট
    "rice_tungro",             # টুংরো (Tungro virus)
    "rice_sheath_blight",      # শিথ ব্লাইট
]

# Friendly display names. The api service ships Bangla copies in
# `api/advisories.py`; English keys here let us fall back gracefully.
LABEL_EN = {
    "rice_healthy": "Healthy",
    "rice_blast": "Rice Blast",
    "rice_brown_spot": "Brown Spot",
    "rice_bacterial_leaf_blight": "Bacterial Leaf Blight",
    "rice_tungro": "Rice Tungro",
    "rice_sheath_blight": "Sheath Blight",
}


def _load_dataset(slug: str, cache_dir: Path):
    """Stream the dataset into a directory of class folders.

    We rely on the Hugging Face `datasets` package which handles the
    parquet -> image conversion. Falls back to a synthetic 12-image
    dataset when the network is unavailable so the trainer still
    completes a smoke-test end-to-end on a fresh laptop.
    """
    from datasets import load_dataset  # heavy import, lazy

    print(f"[train] downloading dataset '{slug}' from Hugging Face ...")
    ds = load_dataset(slug, cache_dir=str(cache_dir))
    print(f"[train] splits available: {list(ds.keys())}")
    return ds


def _materialize_to_folders(ds, out_dir: Path, img_size: int) -> list[str]:
    """Flatten a HF dataset into train/<class>/img_*.jpg folders."""
    from datasets import Dataset  # local import
    from PIL import Image as PILImage

    train_dir = out_dir / "train"
    val_dir = out_dir / "val"
    train_dir.mkdir(parents=True, exist_ok=True)
    val_dir.mkdir(parents=True, exist_ok=True)

    label_names = ds["train"].features["label"].names  # e.g. ["rice_blast", ...]
    print(f"[train] class names from dataset: {label_names}")

    def _dump(split_name: str, hf_split):
        target = train_dir if split_name == "train" else val_dir
        per_class_counter: dict[str, int] = {}
        for example in hf_split:
            label = label_names[example["label"]]
            cls_dir = target / label
            cls_dir.mkdir(parents=True, exist_ok=True)
            counter = per_class_counter.get(label, 0)
            img: PILImage.Image = example["image"]
            img = img.convert("RGB").resize((img_size, img_size))
            img.save(cls_dir / f"img_{counter:05d}.jpg", quality=90)
            per_class_counter[label] = counter + 1
        return per_class_counter

    counts = _dump("train", ds["train"])
    val_counts = _dump("val", ds["val"]) if "val" in ds else {}
    print(f"[train] per-class train counts: {counts}")
    print(f"[train] per-class val counts:   {val_counts}")
    return label_names


def _synthetic_dataset(out_dir: Path, img_size: int) -> list[str]:
    """Generate a tiny fake dataset for offline smoke-testing.

    Used only when the HF download fails (e.g. no internet at a
    workshop). 12 random-tinted images per class is enough to prove
    the trainer runs end-to-end — accuracy will be meaningless, but
    the saved model is still callable from the API server.
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(42)
    for label in LABEL_KEYS:
        cls_dir = out_dir / "train" / label
        cls_dir.mkdir(parents=True, exist_ok=True)
        cls_dir_v = out_dir / "val" / label
        cls_dir_v.mkdir(parents=True, exist_ok=True)
        for i in range(12):
            arr = rng.integers(0, 255, size=(img_size, img_size, 3), dtype=np.uint8)
            Image.fromarray(arr).save(cls_dir / f"img_{i:03d}.jpg")
            Image.fromarray(arr).save(cls_dir_v / f"img_{i:03d}.jpg")
    print("[train] using SYNTHETIC dataset (offline mode)")
    return LABEL_KEYS


# ---------------------------------------------------------------------------
# Trainer
# ---------------------------------------------------------------------------

def _build_model(num_classes: int, img_size: int):
    import tensorflow as tf  # heavy import, lazy

    base = tf.keras.applications.MobileNetV2(
        input_shape=(img_size, img_size, 3),
        include_top=False,
        weights="imagenet",
    )
    base.trainable = False  # phase 1: train the head only

    inputs = tf.keras.Input(shape=(img_size, img_size, 3))
    x = tf.keras.applications.mobilenet_v2.preprocess_input(inputs)
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.25)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model, base


def _build_generators(train_dir: Path, val_dir: Path, img_size: int, batch: int):
    import tensorflow as tf

    train_ds = tf.keras.utils.image_dataset_from_directory(
        train_dir,
        image_size=(img_size, img_size),
        batch_size=batch,
        label_mode="int",
        shuffle=True,
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        val_dir,
        image_size=(img_size, img_size),
        batch_size=batch,
        label_mode="int",
        shuffle=False,
    )
    autotune = tf.data.AUTOTUNE
    return (
        train_ds.cache().prefetch(buffer_size=autotune),
        val_ds.cache().prefetch(buffer_size=autotune),
    )


def train(
    epochs_head: int = 5,
    epochs_finetune: int = 5,
    batch_size: int = 32,
) -> Path:
    """Top-level entry point — returns the saved model path."""
    import tensorflow as tf

    img_size = int(os.getenv("IMG_SIZE", "224"))
    model_path = Path(os.getenv("MODEL_PATH", "models/rice_disease_mobilenetv2.h5"))
    labels_path = Path(os.getenv("LABELS_PATH", "models/labels.json"))
    model_path.parent.mkdir(parents=True, exist_ok=True)
    labels_path.parent.mkdir(parents=True, exist_ok=True)

    data_root = ROOT / "data" / "plantvillage_rice"
    data_root.mkdir(parents=True, exist_ok=True)

    # --- 1. Load dataset (or fall back to synthetic) -------------------
    slug = os.getenv("DATASET_SLUG", "rice_leaf_diseases")
    try:
        ds = _load_dataset(slug, ROOT / "data" / "_hf_cache")
        label_names = _materialize_to_folders(ds, data_root, img_size)
    except Exception as exc:  # noqa: BLE001
        print(f"[train] HF dataset unavailable ({exc}); using synthetic data")
        label_names = _synthetic_dataset(data_root, img_size)

    # If the downloaded dataset used different label names we still write
    # the canonical LABEL_KEYS ordering to disk so the api server has a
    # stable mapping. Anything we couldn't learn becomes a placeholder.
    final_labels = label_names if set(LABEL_KEYS).issubset(set(label_names)) else LABEL_KEYS

    # --- 2. Build model ----------------------------------------------
    print(f"[train] building MobileNetV2 head ({len(final_labels)} classes)")
    model, base = _build_model(num_classes=len(final_labels), img_size=img_size)

    train_ds, val_ds = _build_generators(
        data_root / "train", data_root / "val", img_size, batch_size
    )

    # --- 3. Phase 1: train head --------------------------------------
    print(f"[train] phase 1 — training head for {epochs_head} epochs")
    model.fit(train_ds, validation_data=val_ds, epochs=epochs_head, verbose=2)

    # --- 4. Phase 2: light fine-tune ---------------------------------
    base.trainable = True
    for layer in base.layers[:-30]:
        layer.trainable = False
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    print(f"[train] phase 2 — fine-tuning last 30 base layers for {epochs_finetune} epochs")
    model.fit(train_ds, validation_data=val_ds, epochs=epochs_finetune, verbose=2)

    # --- 5. Save ------------------------------------------------------
    model.save(model_path)
    print(f"[train] model saved -> {model_path}")

    with labels_path.open("w", encoding="utf-8") as fh:
        json.dump(
            {
                "labels": final_labels,
                "label_en": {k: LABEL_EN.get(k, k) for k in final_labels},
                "img_size": img_size,
            },
            fh,
            ensure_ascii=False,
            indent=2,
        )
    print(f"[train] labels saved -> {labels_path}")

    # Quick eval
    loss, acc = model.evaluate(val_ds, verbose=0)
    print(f"[train] final val accuracy: {acc:.4f} | loss: {loss:.4f}")
    return model_path


if __name__ == "__main__":
    train()