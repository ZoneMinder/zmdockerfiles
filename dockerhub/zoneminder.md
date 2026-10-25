# ZoneMinder

[ZoneMinder](https://zoneminder.com) is an open-source video surveillance system (CCTV/NVR). This image runs ZoneMinder from the zmrepo packages on Debian stable, for amd64 and arm64. It needs a separate MariaDB or MySQL database. The compose file below starts both.

Source, full docs and issues: [github.com/ZoneMinder/zmdockerfiles](https://github.com/ZoneMinder/zmdockerfiles)

## Quick start

```bash
mkdir zoneminder && cd zoneminder
curl -fsSLO https://raw.githubusercontent.com/ZoneMinder/zmdockerfiles/master/docker-compose.yaml
curl -fsSL -o .env https://raw.githubusercontent.com/ZoneMinder/zmdockerfiles/master/.env.example
# edit .env: set ZM_DB_PASS, MARIADB_ROOT_PASSWORD and TZ
docker compose up -d
```

Open http://localhost:8080/zm and finish ZoneMinder's first-run setup:

- 1.38 starts with authentication off. Turn on OPT_USE_AUTH under Options > Authentication, log in as `admin` / `admin`, then change that password under Options > Users.
- Answer the usage statistics prompt. Until you do, the web UI and image URLs redirect to it.

## Tags

| Tag | What it is |
|---|---|
| `latest`, `1.38`, `1.38.6` | Newest ZoneMinder release |
| `latest-es`, `1.38-es`, `1.38.6-es` | The same, plus the [zmeventnotificationNg](https://github.com/ZoneMinder/zmeventnotificationNg) event server (push, WebSocket, MQTT, object detection hook) |
| `dev`, `dev-es` | Nightly build of ZoneMinder master (odd minor versions such as 1.39). Don't run it on a system you rely on. |

The same tags are on GitHub's registry as `ghcr.io/zoneminder/zoneminder`.

CI rebuilds the images every day. `latest` moves to the next minor release (1.40, 1.42) as soon as zmrepo publishes it. Pin `1.38` if you want to choose when to upgrade.

To run the event server, set `ZM_TAG=latest-es` in `.env`. For object detection, also set `ZMES_USE_HOOKS=yes` and start with `docker compose --profile ml up -d`, which adds the [zoneminder/pyzm-serve](https://hub.docker.com/r/zoneminder/pyzm-serve) container.

## Ports and volumes

| Port | |
|---|---|
| 80 | Web UI (8080 on the host in the compose file), with go2rtc under `/zm/go2rtc/` |
| 8555 tcp/udp | WebRTC |
| 9000 | Event server WebSocket (`-es` tags) |

| Path | |
|---|---|
| `/var/cache/zoneminder` | Events, images and cache. This one gets big. |
| `/var/log/zm` | ZoneMinder logs |
| `/config` | go2rtc, event server config and certificates |
| `/dev/shm` | tmpfs for each monitor's frame buffer, 1 GiB in the compose file |

## Main settings

| Variable | Default | |
|---|---|---|
| `ZM_DB_HOST` | `db` | `host`, `host:port` or `localhost:/path/to/socket` |
| `ZM_DB_NAME` / `ZM_DB_USER` | `zm` / `zmuser` | |
| `ZM_DB_PASS` / `ZM_DB_PASS_FILE` | required | Use the `_FILE` form with Docker secrets |
| `TZ` | `UTC` | Give the database the same value |
| `ZM_PUBLIC_URL` | | Address browsers use, e.g. `http://zm.lan:8080`. Set GO2RTC_PATH to it plus `/zm/go2rtc` for go2rtc live view. |
| `PUID` / `PGID` | `33` / `33` | Match the owner of your bind mounts |
| `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS` | | Outgoing mail through msmtp |

The [README](https://github.com/ZoneMinder/zmdockerfiles#configuration) lists every variable, plus hardware decoding, GPU detection and the event server config.

## Upgrading from the 2021 images

The old `zoneminderhq/zoneminder:latest-el7` and `latest-ubuntu18.04` images ran MySQL inside the ZoneMinder container. To move to this image, dump the database from the old container and load it into the compose stack's MariaDB. The schema upgrades to 1.38 on first start. See [Upgrading from the old images](https://github.com/ZoneMinder/zmdockerfiles#upgrading-from-the-old-images).

## Help

- Questions: [ZoneMinder forums](https://forums.zoneminder.com/)
- ZoneMinder docs: [zoneminder.readthedocs.io](https://zoneminder.readthedocs.io/)
- Bugs in the image: [GitHub issues](https://github.com/ZoneMinder/zmdockerfiles/issues). Include your compose file (passwords removed) and the output of `docker compose logs zoneminder`.
