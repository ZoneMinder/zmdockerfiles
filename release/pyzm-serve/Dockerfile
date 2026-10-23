# Remote ML inference server for zmeventnotificationNg hooks.
# The ES hook (zm_detect.py) sends frames here through objectconfig.yml -> remote.ml_gateway.
#
#   docker build -t zoneminder-pyzm-serve release/pyzm-serve
#   docker run -p 5000:5000 -v pyzm-models:/models zoneminder-pyzm-serve
#
# Models are downloaded into /models on first start if missing (PYZM_MODELS, comma separated).
FROM python:3.12-slim

ARG PYZM_VERSION=2.5.4

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "pyzm[serve]==${PYZM_VERSION}" opencv-python-headless \
    && useradd --system --home /models pyzm \
    && install -d -o pyzm -g pyzm /models

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.py /usr/local/bin/pyzm-healthcheck

ENV PYZM_MODELS="YOLO ONNX=yolo11s" \
    PYZM_PROCESSOR="cpu" \
    PYZM_PORT="5000" \
    PYZM_ASSETS_URL="https://github.com/pliablepixels/zmes_ai_assets/raw/master/models/ultralytics"

VOLUME /models
EXPOSE 5000
USER pyzm
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s CMD ["pyzm-healthcheck"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
