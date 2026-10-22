#!/bin/bash
set -euo pipefail

# With no GPU visible, OpenCV quietly runs CUDA models on the CPU, and pyzm keeps reporting
# "gpu". Stop here instead, so a missing GPU shows up as a stopped container.
if [[ "$PYZM_PROCESSOR" == gpu ]]; then
    gpus=$(python -c 'import cv2; print(cv2.cuda.getCudaEnabledDeviceCount())' 2>/dev/null || echo 0)
    if (( gpus < 1 )); then
        echo "PYZM_PROCESSOR=gpu but OpenCV sees no CUDA device." >&2
        echo "Use the :cuda image, give the container the GPU (see compose.gpu.yaml)," >&2
        echo "and check that nvidia-smi works inside it. Or set PYZM_PROCESSOR=cpu." >&2
        exit 1
    fi
    echo "OpenCV sees $gpus CUDA device(s)"
fi

# PYZM_MODELS is comma separated. Each entry is a model file name, optionally published under
# another name: "YOLO ONNX=yolo11s" serves yolo11s.onnx as "YOLO ONNX", the name the default
# zmeventnotificationNg objectconfig.yml asks for.
IFS=',' read -r -a entries <<< "$PYZM_MODELS"
models=()
mkdir -p /models/ultralytics
for entry in "${entries[@]}"; do
    entry="$(echo "$entry" | sed 's/^ *//; s/ *$//')"
    [[ -n "$entry" ]] || continue
    file="${entry##*=}"
    target="/models/ultralytics/${file}.onnx"
    if [[ ! -s "$target" ]]; then
        echo "Downloading ${file}.onnx"
        curl -fsSL --retry 3 -o "${target}.part" "${PYZM_ASSETS_URL}/${file}.onnx"
        mv "${target}.part" "$target"
    fi
    models+=("$entry")
done

args=(--models "${models[@]}" --base-path /models --processor "$PYZM_PROCESSOR" --port "$PYZM_PORT")
if [[ -n "${PYZM_AUTH_PASSWORD:-}" ]]; then
    args+=(--auth --auth-user "${PYZM_AUTH_USER:-admin}" --auth-password "$PYZM_AUTH_PASSWORD"
           --token-secret "${PYZM_TOKEN_SECRET:?set PYZM_TOKEN_SECRET when auth is on}")
fi
exec python -m pyzm.serve "${args[@]}" "$@"
