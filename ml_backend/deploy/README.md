# Krishi AI — crop disease API

Backend for the Krishi AI app. Potato, tomato, eggplant and maize leaf photos
are classified here; rice runs on the phone.

- `GET /health`: which crops have a model
- `POST /predict`: multipart `crop` + `file`, returns the top-3 labels with a verdict
- `/docs`: try it in the browser

Runs `model.tflite` with LiteRT (no TensorFlow), so a 512 MB instance is enough.
