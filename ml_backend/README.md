# Krishi AI — ML Backend

A small FastAPI service that hosts the **online crop disease models**
(potato, tomato, eggplant, maize). Rice runs on-device in the app, so
these larger models stay out of the APK. `POST /predict` takes a `crop`
and a leaf photo and returns top-K labels with the model's verdict; see
SETUP.md → "Add a crop model" for the folder layout and label keys.

```
┌────────┐  crop + leaf photo  ┌──────────┐   models/<crop>/
│ Flutter├────────────────────►│ FastAPI  ├──────────────────┐
│ (app)  │                     │ /predict │  model.tflite    │
│        │◄────────────────────┤          │◄─────────────────┘
└────────┘  JSON: top-K labels └──────────┘
            + verdict + note
```

## Layout

```
ml_backend/
├── api/
│   ├── advisories.py     # Bangla disease content (symptoms/causes/…)
│   └── main.py           # FastAPI app: /predict (crop + file), /health
├── training/
│   └── train_rice.py     # MobileNetV2 transfer-learning trainer
├── models/<crop>/        # model.tflite|keras + labels.txt (+ meta.json)
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

The server starts without any models; `/health` then reports every crop
as `false` and `/predict` answers 503, which the app shows as
"মডেল এখনো প্রস্তুত নয়".

## Pointing Flutter at the backend

In `lib/core/config/api_config.dart` the base URL defaults to
`http://10.0.2.2:8000` (Android emulator → host machine). For a real device
or iOS simulator override `KRISHI_API_BASE_URL` when running the app, or
edit the constant directly.

```
flutter run --dart-define=KRISHI_API_BASE_URL=http://192.168.0.42:8000
```

When the network call fails (server down, no Wi-Fi), `CropDoctorScreen`
tells the farmer what went wrong and offers a retry; rice keeps working
offline.
