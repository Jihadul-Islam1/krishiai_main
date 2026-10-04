# Setup — Krishi AI ML Backend

This doc explains every step from a clean laptop to a running `/predict`
endpoint that the Flutter app can call.

## 1. Prerequisites

| Tool    | Tested version |
|---------|----------------|
| Python  | 3.10 – 3.12    |
| pip     | 23+            |
| Git     | any            |

A GPU is **not** required — training falls back to CPU. With 6 rice
classes and a MobileNetV2 backbone expect ~25 minutes on a modern
laptop, ~3 minutes on a free Colab T4.

## 2. Create a virtual env & install deps

```bash
# from the repo root
cd d:/KrishiAi-main

python -m venv ml_backend/.venv
# Windows (PowerShell)
ml_backend\.venv\Scripts\Activate.ps1
# macOS / Linux
source ml_backend/.venv/bin/activate

pip install --upgrade pip
pip install -r ml_backend/requirements.txt
```

If `tensorflow` install fails on Windows, install the CPU-only wheel:

```bash
pip install tensorflow-cpu==2.16.1
```

## 3. Configure

```bash
cp ml_backend/.env.example ml_backend/.env
```

Defaults work for a local dev box. The only thing worth touching is
`DATASET_SLUG` if you point at a different Hugging Face mirror.

## 4. Train the model

```bash
python -m ml_backend.training.train_rice
```

This:

1. Downloads the PlantVillage rice subset (~120 MB).
2. Materialises it into `data/plantvillage_rice/{train,val}/<class>/...`.
3. Trains a MobileNetV2 head (5 epochs) then fine-tunes the last 30
   layers (5 more epochs).
4. Writes:
   - `ml_backend/models/rice_disease_mobilenetv2.h5`
   - `ml_backend/models/labels.json`

You can shorten training for a smoke-test:

```bash
EPOCHS_HEAD=2 EPOCHS_FINETUNE=1 python -m ml_backend.training.train_rice
```

## 5. Run the server

```bash
python -m ml_backend.api.main
# → http://localhost:8000/docs
```

Try it:

```bash
curl -F "file=@./test_leaf.jpg" http://localhost:8000/predict
```

Expected response shape (abridged):

```json
{
  "model_version": "rice-mobilenetv2-1.0",
  "inference_ms": 87,
  "top_k": [
    {"label": "rice_blast", "label_bn": "ধানের ব্লাস্ট (Rice Blast)",
     "label_en": "Rice Blast", "confidence": 0.92, "severity": "high"},
    {"label": "rice_brown_spot", "label_bn": "বাদামী দাগ (Brown Spot)",
     "label_en": "Brown Spot", "confidence": 0.05, "severity": "medium"}
  ],
  "is_confident": true,
  "probable": true,
  "advisory": {
    "name_bn": "ধানের ব্লাস্ট (Rice Blast)",
    "severity": "high",
    "symptoms": ["…"], "causes": ["…"], "management": ["…"], "prevention": ["…"]
  },
  "note_bn": "এটি একটি সম্ভাব্য রোগ নির্ণয় …"
}
```

## 6. Plug into Flutter

The Flutter app already calls the backend. By default it expects
`http://10.0.2.2:8000` (Android emulator → host loopback). Override at
runtime:

```bash
flutter run --dart-define=KRISHI_API_BASE_URL=http://192.168.0.42:8000
```

## 7. When training fails (offline workshops)

If the Hugging Face download fails, the trainer automatically falls back
to a 72-image synthetic dataset. The pipeline still runs end-to-end and
the saved model is callable, but predictions will be uninformative.
Use this mode only to prove the wiring.