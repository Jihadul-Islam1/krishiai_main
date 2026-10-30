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

### Add a crop model

The app diagnoses **rice on-device**; potato, tomato, eggplant and maize go
through this server. Put each trained model in its own folder:

```
ml_backend/models/
├── tomato/
│   ├── model.tflite      # or model.keras — the notebook exports both
│   ├── labels.txt        # one label per line, in model output order
│   └── meta.json         # optional: rename the notebook's *_model_meta.json
├── potato/ …
├── eggplant/ …
└── maize/ …
```

`labels.txt` must use the keys the app knows (see
`lib/data/library/<crop>_disease_info.dart`):

| crop | labels |
|------|--------|
| potato | `early_blight`, `late_blight`, `healthy` |
| tomato | `bacterial_spot`, `early_blight`, `late_blight`, `leaf_mold`, `septoria_leaf_spot`, `spider_mites`, `target_spot`, `yellow_leaf_curl_virus`, `mosaic_virus`, `healthy` |
| eggplant | `leaf_spot`, `mosaic_virus`, `little_leaf`, `wilt`, `white_mold`, `insect_pest`, `healthy` |
| maize | `gray_leaf_spot`, `common_rust`, `northern_leaf_blight`, `fall_armyworm`, `healthy` |

Add a `not_leaf` class (photos of soil, hands, other plants) so the app can
say "this isn't a tomato leaf". A label the app doesn't know still works —
it shows `classes_bn` from `meta.json` with generic advice.

Models take float32 RGB in **0–255** (preprocessing inside the model, as in
`ml/rice_disease_training.ipynb`). `meta.json` may set
`confident_threshold` (default 0.5) and `min_threshold` (default 0.4); pick
them from the notebook's threshold table.

`GET /health` lists which crops have model files, so you can check a new
model was picked up without restarting the app.

Try it:

```bash
curl -F "crop=tomato" -F "file=@./test_leaf.jpg" http://localhost:8000/predict
```

Expected response shape:

```json
{
  "crop": "tomato",
  "model_version": "tomato-mobilenetv3large",
  "inference_ms": 87,
  "top_k": [
    {"label": "late_blight", "label_bn": "নাবী ধসা রোগ",
     "label_en": "Late Blight", "confidence": 0.71, "severity": "medium"},
    {"label": "early_blight", "label_bn": "আগাম ধসা রোগ",
     "label_en": "Early Blight", "confidence": 0.12, "severity": "medium"}
  ],
  "is_confident": true,
  "probable": true,
  "advisory": {},
  "note_bn": "এটি এআই-এর প্রাথমিক পরামর্শ, চূড়ান্ত রোগ নির্ণয় নয়। …"
}
```

Errors the app explains to the farmer: `400` (unknown crop / not an image)
and `503` (no model for that crop yet → "মডেল এখনো প্রস্তুত নয়").

## 6. Plug into Flutter

The Flutter app already calls the backend. By default it uses the deployed
server, `https://krishiai-api-n0rk.onrender.com`. To test against a local
server instead (`10.0.2.2` is the Android emulator → host loopback; use the
laptop's LAN IP from a real phone):

```bash
flutter run --dart-define=KRISHI_API_BASE_URL=http://10.0.2.2:8000
```

### Deploy (HTTPS for real phones)

`ml_backend/deploy/` holds a Dockerfile that runs `model.tflite` with LiteRT
instead of TensorFlow (~170 MB RAM), so a free 512 MB instance is enough.

```bash
python ml_backend/deploy/make_deploy.py   # → build/server_deploy/
```

Push `build/server_deploy/` to its own GitHub repo and create a Docker web
service from it (e.g. Render, free instance). The container listens on
`$PORT`. The live service is `https://krishiai-api-n0rk.onrender.com`
(Render added `-n0rk` because `krishiai-api` was taken); if it moves, update
`defaultValue` in `lib/core/config/api_config.dart`.

The free instance sleeps after 15 idle minutes and takes up to a minute to
wake; the app waits up to 90 s and shows "সার্ভার জাগছে" meanwhile.

## 7. When training fails (offline workshops)

If the Hugging Face download fails, the trainer automatically falls back
to a 72-image synthetic dataset. The pipeline still runs end-to-end and
the saved model is callable, but predictions will be uninformative.
Use this mode only to prove the wiring.