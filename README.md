# zmdockerfiles

Docker images and a compose stack for running ZoneMinder, with an optional event server
([zmeventnotificationNg](https://github.com/ZoneMinder/zmeventnotificationNg)) and object detection.

| Path | What it is |
|---|---|
| `release/zoneminder/` | ZoneMinder installed from the zmrepo packages on Debian stable. Two targets: `zm` and `zm-es`. |
| `release/pyzm-serve/` | ML inference server the event server hook sends frames to. |
| `docker-compose.yaml` | MariaDB + ZoneMinder, with pyzm-serve behind the `ml` profile. Pulls the published images. |
| `compose.build.yaml` | Override that builds the images from this repo instead. |
| `compose.gpu.yaml` | Override that runs pyzm-serve on an NVIDIA GPU. |
| `tests/smoke.sh` | End-to-end test of the whole stack. CI runs it before publishing. |
| `tests/pyzm-cuda.sh` | Test for the CUDA pyzm-serve image. |

## Images

All images are on Docker Hub for amd64 and arm64. `zoneminderhq/zoneminder` carries the same tags
as `zoneminder/zoneminder`, so anyone still pulling the old name gets current images.

| Image | Tags |
|---|---|
| `zoneminder/zoneminder` | `latest`, `1.38`, `1.38.6`: newest release. `dev`, `1.39`, ...: nightly development build. |
| | Each tag also has an `-es` version with the event server: `latest-es`, `1.38-es`, `dev-es`. |
| `zoneminder/pyzm-serve` | `latest`, `2.5.4`: CPU, amd64 and arm64. `cuda`, `2.5.4-cuda`: NVIDIA GPU, amd64 only. |

CI rebuilds every day. `latest` moves to a new minor release (1.40, 1.42) as soon as zmrepo
publishes it, with no change to this repo. Pin `1.38` if you want to choose when to upgrade.
The `dev` tags follow ZoneMinder master, which uses the odd minor versions. Don't run them on a
system you rely on.

## Quick start

```bash
cp .env.example .env     # set ZM_DB_PASS, MARIADB_ROOT_PASSWORD and TZ
docker compose up -d
```

Open http://localhost:8080/zm and finish ZoneMinder's own first-run setup:

- 1.38 starts with authentication off. Turn on OPT_USE_AUTH under Options > Authentication, log in
  as `admin` / `admin`, then change that password under Options > Users.
- 1.39 and later (the `dev` tags) start with authentication on. The first login page asks you to
  set the `admin` password or turn authentication off.
- Answer the usage statistics prompt. Until you do, the web UI and image URLs redirect to it,
  and the event server hook can't fetch frames.

For live view through go2rtc, set `ZM_PUBLIC_URL` in `.env` to the address you open ZoneMinder
at, using a hostname, for example `http://zm.lan:8080`. Then set Options > System > GO2RTC_PATH
to that address plus `/zm/go2rtc`, so `http://zm.lan:8080/zm/go2rtc`, and turn on go2rtc for each
monitor. The container serves go2rtc under ZoneMinder's own address, so the browser's WebSocket
passes go2rtc's origin check. `ZM_PUBLIC_URL` also points that hostname at the container itself,
because ZoneMinder calls the same URL from inside it, and a host firewall often blocks a container
from reaching its own published port. With an IP address instead of a name, that part depends on
your firewall.

`docker compose ps` shows the container's health. It reports unhealthy when Apache stops serving
`/zm/`, when the `zmdc.pl` daemon is gone, or when the database doesn't answer.
`docker inspect --format '{{json .State.Health}}' zoneminder-zoneminder-1` shows which. Plain Docker
doesn't restart unhealthy containers, so a database outage leaves ZoneMinder running and capturing
until the database comes back. If `zmdc.pl` itself dies, the container exits and the restart policy
starts it again. A single camera going offline doesn't count as unhealthy. ZoneMinder's own
`zmwatch` restarts stuck capture daemons, and the API shows per-monitor status.

## Event server and object detection

The event server reads ZoneMinder's shared memory, so it has to run in the same container as
ZoneMinder. That is what the `zm-es` image is. The ML models don't have that constraint, so
they run in their own container and the hook sends JPEG frames to it over HTTP.

```bash
# push notifications, WebSocket (port 9000) and MQTT, no detection
ZM_TAG=latest-es docker compose up -d

# plus object detection
ZM_TAG=latest-es ZMES_USE_HOOKS=yes docker compose --profile ml up -d
```

Set these in `.env` rather than on the command line once you have settled on a setup.

`ZMES_USE_HOOKS` only takes effect the first time the container creates the event server config.
If you started without hooks and turn them on later, set `use_hooks: "yes"` in
`/config/es/zmeventnotification.yml`, or delete that file, and restart. The log warns when the two
disagree.

On first start the container copies the event server config into the `config` volume, at
`/config/es/`. Edit the files there and restart the container. The `ZMES_*` variables only
apply to that first copy. Delete a file to have it regenerated.

- `secrets.yml` holds the ZM user and password the hook logs in with. Once authentication is
  on, put your ZoneMinder login there as `ZM_USER` and `ZM_PASSWORD`, then restart the container.
- `objectconfig.yml` points at `http://pyzm-serve:5000` and only runs object detection. Face and
  licence plate recognition need extra models or API keys, so they are left off.
- The event server checks WebSocket logins (zmNinja, zmNinjaNG) against ZoneMinder's users even
  while ZoneMinder's own authentication is off. A fresh 1.38 install's login is then `admin` /
  `admin`, so change that password, or turn off `auth` in `zmeventnotification.yml`.
- WebSocket TLS uses `/config/ssl/es.crt` and `es.key`. The container generates a self-signed pair
  if none exists. zmNinjaNG needs a real certificate for picture notifications, so put yours there.

pyzm-serve downloads `yolo11s` on first start and serves it as `YOLO ONNX`, the name
`objectconfig.yml` asks for. To use a different model set `PYZM_MODELS`, for example
`PYZM_MODELS=YOLO ONNX=yolo26s`.

### GPU detection

The `cuda` tag runs detection on an NVIDIA GPU. pyzm runs models through OpenCV, and the
OpenCV packages on PyPI have no CUDA support, so this image carries its own OpenCV build with
CUDA and cuDNN. It is amd64 only, supports Turing (GTX 16xx, RTX 20xx) and newer cards, and is
about 3 GB to download.

The host needs the NVIDIA driver and the
[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).
Check with `docker run --rm --gpus all ubuntu nvidia-smi`, then add `compose.gpu.yaml`:

```bash
docker compose -f docker-compose.yaml -f compose.gpu.yaml --profile ml up -d
```

If the container can't see a GPU, it exits with a message saying so, rather than running on the
CPU. pyzm moves a model to the CPU when CUDA fails at runtime, and retries the GPU later. The
container's health check reports unhealthy while that's happening, and the logs show the CUDA error.
To run the `cuda` image on the CPU anyway, set `PYZM_PROCESSOR=cpu`.

CI builds this image and checks that OpenCV has CUDA and that detection works, but GitHub's
runners have no GPU, so nothing tests it on a GPU before release. If it doesn't work on your
card, open an issue with the `pyzm-serve` logs and the output of `nvidia-smi`.

## Configuration

ZoneMinder container environment:

| Variable | Default | |
|---|---|---|
| `ZM_DB_HOST` | `db` | `host`, `host:port` or `localhost:/path/to/socket` |
| `ZM_DB_NAME` | `zm` | |
| `ZM_DB_USER` | `zmuser` | |
| `ZM_DB_PASS` / `ZM_DB_PASS_FILE` | required | Use the `_FILE` form with Docker secrets |
| `ZM_DB_SSL_CA_CERT`, `ZM_DB_SSL_CLIENT_CERT`, `ZM_DB_SSL_CLIENT_KEY` | | TLS to the database |
| `ZM_SERVER_HOST` | | Server name for multi-server installs |
| `ZM_PUBLIC_URL` | | The address browsers use, e.g. `http://zm.lan:8080`. Needed for go2rtc live view, see above. |
| `TZ` | `UTC` | Applied to the OS and PHP. Give the database the same value, as the compose file does. |
| `ZM_ES_ENABLE` | `1` in `-es` images | Writes OPT_USE_EVENTNOTIFICATION to `conf.d`, which takes priority over the UI setting |
| `ZM_DB_WAIT_TIMEOUT` | `180` | Seconds to wait for the database |
| `NO_START_ZM` | `0` | `1` starts Apache and the database checks but not ZoneMinder, for debugging |
| `PUID` / `PGID` | `33` / `33` | Run ZoneMinder, Apache and go2rtc as this user and group. See below. |
| `SMTP_HOST` | | Mail server. Setting it writes `/etc/msmtprc`. See below. |
| `SMTP_PORT` | `587` | |
| `SMTP_TLS` | `starttls`, or `tls` on port 465 | `starttls`, `tls` or `off` |
| `SMTP_USER` / `SMTP_PASS` / `SMTP_PASS_FILE` | | Login. Leave `SMTP_USER` empty for a server without one. |
| `SMTP_FROM` | `SMTP_USER` | Sender address |

The database settings go to `/etc/zm/conf.d/03-docker.conf` on every start. `zm.conf` stays as
the package installed it. Apart from creating and upgrading the schema, the container doesn't
change ZoneMinder's settings. Everything else is set in the web UI, as on any other install.

At start the container also:

- creates the schema if the database is empty, otherwise runs `zmupdate.pl` to upgrade it, then
  runs `zmupdate.pl --freshen`, which also replaces the shipped `ZM_AUTH_HASH_SECRET` with a random one
- adds `www-data` to the groups that own any passed-through `/dev/dri`, `/dev/video*` or
  `/dev/nvidia*` devices

### User and group IDs

The container runs as `www-data`, which is 33:33. If your volumes are bind mounts that belong to
a user on the host, set `PUID` and `PGID` to that user's IDs, for example `PUID=1000 PGID=1000`.
At start the container gives `www-data` those IDs and re-owns the files it owned before: the
image's own files, `/config`, `/var/log/zm`, and the top two levels of the events folder.

It doesn't walk the whole events folder, because that can take hours. If you change the IDs on
an install that already has events, ZoneMinder can still record, but it can't delete the old
events until you re-own them once. The log says so when that's needed:

```bash
docker compose exec zoneminder chown -R www-data:www-data /var/cache/zoneminder
```

### Email

Set `SMTP_HOST`, plus `SMTP_USER` and `SMTP_PASS` if the server needs a login, and the container
writes an msmtp config for it. Then in ZoneMinder's Options > Email turn on `OPT_EMAIL`,
`NEW_MAIL_MODULES` and `SSMTP_MAIL`, set `SSMTP_PATH` to `/usr/bin/msmtp`, and fill in the
addresses. The container doesn't change those settings for you.

To check the settings without ZoneMinder:

```bash
docker compose exec -u www-data zoneminder sh -c \
  'printf "Subject: test\n\nhello\n" | msmtp -t you@example.com'
```

Volumes:

| Path | |
|---|---|
| `/var/cache/zoneminder` | Events, images and the cache. This one gets big. |
| `/var/log/zm` | ZoneMinder logs. The main ones are also copied to `docker logs`. |
| `/config` | `go2rtc.yaml`, event server config and certificates |
| `/dev/shm` | tmpfs, 1 GiB by default (`ZM_SHM_SIZE`). ZoneMinder keeps each monitor's frame buffer here. |

Ports: 80 (web, with go2rtc's API and page under `/zm/go2rtc/`), 8555 tcp/udp (WebRTC),
9000 (event server).

### Hardware decoding

Uncomment the `devices:` block in `docker-compose.yaml`, then set DecoderHWAccelName and
DecoderHWAccelDevice on the monitor. The image ships the Mesa VA-API drivers, plus Intel's
media driver on amd64. `docker compose exec zoneminder vainfo` shows what the container can see.

## Upgrading from the old images

The old `zoneminderhq/zoneminder` images ran MySQL inside the ZoneMinder container. Dump the
database from the old container and load it into the new one:

```bash
docker exec old-zoneminder mysqldump --single-transaction --routines --triggers zm > zm.sql
docker compose up -d --wait db
docker compose exec -T db sh -c 'exec mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" zm' < zm.sql
docker compose up -d
```

`old-zoneminder` is the old container's name. The single quotes matter: the root password is in
`.env`, which the `db` container has but your shell doesn't.

`zmupdate.pl` upgrades the schema to 1.38 on first start, and the logs show each step. Events
live in the same place (`/var/cache/zoneminder/events`), so point the `events` volume at the old
directory, or bind mount it.

## Building

```bash
# same as the published images
docker compose -f docker-compose.yaml -f compose.build.yaml build
ZM_TARGET=zm-es ZM_TAG=local-es docker compose -f docker-compose.yaml -f compose.build.yaml up -d --build

# or straight from the Dockerfile
docker build -t zoneminder:local release/zoneminder
docker build --target zm-es --build-arg ZM_CHANNEL=master -t zoneminder:dev-es release/zoneminder
```

Build arguments:

| Argument | Default | |
|---|---|---|
| `ZM_CHANNEL` | `release` | `release` finds the newest `release-1.x` channel on zmrepo. `master` is the nightly build. A directory name such as `release-1.38` stays on that release. |
| `ZM_VERSION` | newest | Exact package version, for example `1.38.6+trixie1` |
| `BASE_IMAGE` | `debian:stable-slim` | Tracks the current Debian release. `ubuntu:26.04` and `ubuntu:24.04` also work, because zmrepo builds for Ubuntu LTS too. The scripts read the codename from the image, so you don't need to change anything else. |

Docker caches the "newest version" lookup with the rest of the layer. Use `--no-cache`, or pass
`ZM_VERSION` as CI does, to pick up a newer package. s6-overlay, go2rtc, zmeventnotificationNg
and pyzm are pinned in `ARG` lines at the top of each Dockerfile.

## Testing

`tests/smoke.sh` builds the `zm-es` and pyzm-serve images and starts the full stack. It then
checks schema creation, the web UI and API, go2rtc, and capture from an RTSP test stream.

The test camera loops a photo of a bus that switches between blurred and sharp, so ZoneMinder's
own motion detection opens the events. `tests/es-client.pl` then acts like zmNinja: it logs in to
the event server over the TLS WebSocket and waits for the alarms. The start alarm has to carry the
hook's detection, and the event's notes have to show it.

After that it checks PUID/PGID and mail, stops the database for 45 seconds, then restarts the
container to check init runs cleanly a second time and that the log has no PHP fatal errors. It
takes about five minutes once the images are cached.

```bash
tests/smoke.sh                       # newest release
ZM_CHANNEL=master tests/smoke.sh     # nightly
```

The `images` workflow runs it for both channels on every pull request, on every push to master and
once a day. On master it then builds amd64 and arm64 and pushes to Docker Hub.

The `pyzm-serve-cuda` workflow builds the CUDA image when `release/pyzm-serve` changes and twice a
week, runs `tests/pyzm-cuda.sh`, and pushes from master. The first build compiles OpenCV for seven
GPU generations. That took 6 minutes on a 16-core machine, and takes longer on GitHub's 4-core
runners. Later builds reuse it from the Actions cache. To build it yourself:

```bash
docker build -f release/pyzm-serve/Dockerfile.cuda -t pyzm-serve:cuda release/pyzm-serve
# much faster: compile for your card only, e.g. 8.6 for RTX 30xx
docker build -f release/pyzm-serve/Dockerfile.cuda --build-arg CUDA_ARCH_BIN=8.6 \
  -t pyzm-serve:cuda release/pyzm-serve
tests/pyzm-cuda.sh pyzm-serve:cuda
GPU=1 tests/pyzm-cuda.sh pyzm-serve:cuda   # also detect on the GPU and compare timings
```

Pushing needs the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets, with a token that can write
to both the `zoneminder` and `zoneminderhq` organisations.

To try the publishing steps without touching the real images, run either workflow by hand from
the Actions tab and tick "test_push". It runs from any branch and pushes to `-test` repos instead:
`zoneminder/zoneminder-test`, `zoneminderhq/zoneminder-test` and `zoneminder/pyzm-serve-test`.
Create those repos first and give the CI user write access to them, as for the real ones.

## Reporting problems

Use the [forums](https://forums.zoneminder.com/) for questions. For bugs in these images, open an
issue with your compose file (passwords removed) and the output of `docker compose logs zoneminder`.

## Docker Hub pages

The overview and short description of each Docker Hub repo come from `dockerhub/*.md` and
`.github/workflows/dockerhub-description.yml`. Edit them there, and the change goes live when it
reaches master. Editing a page on hub.docker.com directly gets overwritten by the next run.

## License

GPL-2.0-or-later, the same as ZoneMinder. See [LICENSE](LICENSE). The images contain other
software under its own licenses, including Debian packages, zmeventnotificationNg and pyzm, and
the YOLO model weights that pyzm-serve downloads on first start (Ultralytics, AGPL-3.0).
