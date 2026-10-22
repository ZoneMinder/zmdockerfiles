#!/bin/bash
# Test the pyzm-serve CUDA image on a machine without a GPU, as CI runs it.
#   tests/pyzm-cuda.sh [image]        default zoneminder-pyzm-serve:cuda
#
# Checks that OpenCV in the image has CUDA and cuDNN, that the container refuses to start when
# asked for the GPU and none is visible, and that detection works on the CPU. Nothing here runs
# on a GPU, so it can't prove GPU inference works.
set -euo pipefail

image="${1:-zoneminder-pyzm-serve:cuda}"
name="pyzm-cuda-test-$$"
port=15000
work=$(mktemp -d)
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; docker logs "$name" 2>&1 | tail -30 >&2 || true; exit 1; }
step() { echo "==> $*"; }

step "OpenCV build"
docker run --rm --entrypoint python "$image" -c '
import cv2, re
info = cv2.getBuildInformation()
for what in ("NVIDIA CUDA", "cuDNN"):
    assert re.search(what + r":\s+YES", info), what + " missing"
print("OpenCV", cv2.__version__, re.search(r"NVIDIA GPU arch:\s+(.*)", info).group(1).strip())
'

step "refuses to start on the GPU without one"
if out=$(docker run --rm -e PYZM_PROCESSOR=gpu "$image" 2>&1); then
    fail "container started with PYZM_PROCESSOR=gpu and no GPU"
fi
grep -q "sees no CUDA device" <<<"$out" || fail "unexpected output: $out"

step "detection on the CPU"
docker run -d --name "$name" -p "127.0.0.1:$port:5000" -e PYZM_PROCESSOR=cpu "$image" >/dev/null
for _ in $(seq 60); do
    status=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo gone)
    [[ "$status" == healthy ]] && break
    [[ "$status" == gone ]] && fail "container exited"
    sleep 5
done
[[ "$status" == healthy ]] || fail "not healthy after 5 minutes: $status"

curl -fsSL --retry 3 -o "$work/bus.jpg" https://ultralytics.com/images/bus.jpg
result=$(curl -fsS --max-time 60 "http://127.0.0.1:$port/infer" \
    -F type=object -F "name=YOLO ONNX" -F "image=@$work/bus.jpg;type=image/jpeg")
grep -q '"bus"' <<<"$result" || fail "no bus detected: $result"
docker exec "$name" pyzm-healthcheck

echo "PASS: $image"
