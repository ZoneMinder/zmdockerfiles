#!/usr/bin/env python3
"""Healthcheck for pyzm-serve.

Unhealthy when the server doesn't answer, no model has loaded, or a model is running on a
different processor than it asked for. pyzm moves a GPU model to the CPU when CUDA fails, and
keeps answering, so without the last check a broken GPU setup looks healthy.
"""
import json
import os
import sys
import urllib.request

base = f"http://127.0.0.1:{os.environ.get('PYZM_PORT', '5000')}"


def get(path):
    with urllib.request.urlopen(base + path, timeout=4) as resp:
        return json.load(resp)


try:
    health = get("/health")
    models = get("/models")["models"]
except Exception as exc:
    sys.exit(f"unhealthy: server not answering: {exc}")

if not health.get("models_loaded") or not models:
    sys.exit("unhealthy: no models loaded")
for m in models:
    if not m.get("loaded"):
        sys.exit(f"unhealthy: {m['name']} not loaded")
    if m.get("processor") != m.get("requested_processor"):
        sys.exit(f"unhealthy: {m['name']} asked for {m.get('requested_processor')} "
                 f"but runs on {m.get('processor')}")
print("healthy:", ", ".join(f"{m['name']} on {m['processor']}" for m in models))
