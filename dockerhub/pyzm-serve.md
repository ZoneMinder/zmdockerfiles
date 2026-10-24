# pyzm-serve

Object detection server for the ZoneMinder event server ([zmeventnotificationNg](https://github.com/ZoneMinder/zmeventnotificationNg)). The `-es` tags of [zoneminder/zoneminder](https://hub.docker.com/r/zoneminder/zoneminder) send JPEG frames to it over HTTP on port 5000.

Source, full docs and issues: [github.com/ZoneMinder/zmdockerfiles](https://github.com/ZoneMinder/zmdockerfiles)

## Quick start

It's part of the ZoneMinder compose stack, under the `ml` profile:

```bash
ZM_TAG=latest-es ZMES_USE_HOOKS=yes docker compose --profile ml up -d
```

On first start it downloads `yolo11s` into the `/models` volume and serves it as `YOLO ONNX`, the name the event server config asks for. Set `PYZM_MODELS` to use a different model, for example `PYZM_MODELS=YOLO ONNX=yolo26s`.

## Tags

| Tag | What it is |
|---|---|
| `latest`, `2.5.4` | CPU, amd64 and arm64 |
| `cuda`, `2.5.4-cuda` | NVIDIA GPU, amd64 only, about 3 GB. Turing (GTX 16xx, RTX 20xx) and newer. |

The `cuda` tag needs the NVIDIA driver and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on the host. Add `compose.gpu.yaml` from the repo to run it. If the container can't see a GPU it exits with a message. Set `PYZM_PROCESSOR=cpu` to run it on the CPU anyway.
