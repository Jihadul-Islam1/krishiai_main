# Krishi AI — ML Backend

A small FastAPI service that hosts a **rice leaf disease classifier** trained with
transfer learning (MobileNetV2 on PlantVillage). It returns top-K predictions
plus Bangla advisory content, which the Flutter `CropDoctorScreen` consumes.

```
┌────────┐  multipart image    ┌──────────┐    np.float32[6]
│ Flutter├────────────────────►│ FastAPI  ├──────────────────�
│ (app)  │                     │ /predict │   MobileNetV2   │
│        │◄────────────────────┤          │◄────────────────┘
│        │  JSON: top-K + bn    └──────────┘
└────────┘   advisory + note
```

## Layout

```
ml_backend/
├── api/
│   ├── advisories.py     # Bangla disease content (symptoms/causes/…)
│   └── main.py           # FastAPI app, /predict, /health, /model-info
├── training/
│   └── train_rice.py     # MobileNetV2 transfer-learning trainer
├── models/               # .h5 + labels.json (gitignored, generated)
├── data/                 # cached Hugging Face dataset (gitignored)
├── requirements.txt
├── .env.example
└── SETUP.md              # full local setup walkthrough
```

## Quickstart

```bash
# 1. install deps
python -m venv .venv && source .venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install -r ml_backend/requirements.txt

# 2. (optional) train the model — takes 20-40 min on a laptop GPU
python -m ml_backend.training.train_rice

# 3. run the server
python -m ml_backend.api.main
# → http://localhost:8000/docs
```

If you skip step 2 the server still starts — it just falls back to uniform
probabilities and flags every prediction as "uncertain" so the Flutter UI
shows the "expert review" path instead of crashing.

## Pointing Flutter at the backend

In `lib/core/config/api_config.dart` the base URL defaults to
`http://10.0.2.2:8000` (Android emulator → host machine). For a real device
or iOS simulator override `KRISHI_API_BASE_URL` when running the app, or
edit the constant directly.

```
flutter run --dart-define=KRISHI_API_BASE_URL=http://192.168.0.42:8000
```

When the network call fails (server down, no Wi-Fi), `CropDoctorScreen`
transparently falls back to the existing library-only advisor so the demo
never breaks.
