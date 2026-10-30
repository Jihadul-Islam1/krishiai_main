# Krishi AI disease API, for any Docker host (Render, Koyeb, a VPS, ...).
# Built from the folder that make_deploy.py assembles (build/server_deploy/).
FROM python:3.11-slim

RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY --chown=user ml_backend ./ml_backend

# Hosts pass the port in $PORT (Render: 10000).
EXPOSE 8000
CMD uvicorn ml_backend.api.main:app --host 0.0.0.0 --port ${PORT:-8000}
