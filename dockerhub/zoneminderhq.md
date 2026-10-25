# ZoneMinder (mirror)

**This repo mirrors [zoneminder/zoneminder](https://hub.docker.com/r/zoneminder/zoneminder).** CI pushes the same images with the same tags to both, so existing setups that pull `zoneminderhq/zoneminder` keep getting updates. For new installs, use `zoneminder/zoneminder`.

[ZoneMinder](https://zoneminder.com) is an open-source video surveillance system (CCTV/NVR). This image runs ZoneMinder 1.38 from the zmrepo packages on Debian stable, for amd64 and arm64, with a separate MariaDB container.

Source, full docs and issues: [github.com/ZoneMinder/zmdockerfiles](https://github.com/ZoneMinder/zmdockerfiles)

## Quick start

```bash
mkdir zoneminder && cd zoneminder
curl -fsSLO https://raw.githubusercontent.com/ZoneMinder/zmdockerfiles/master/docker-compose.yaml
curl -fsSL -o .env https://raw.githubusercontent.com/ZoneMinder/zmdockerfiles/master/.env.example
# edit .env: set ZM_DB_PASS, MARIADB_ROOT_PASSWORD and TZ
docker compose up -d
```

Open http://localhost:8080/zm and finish ZoneMinder's first-run setup. The compose file pulls `zoneminder/zoneminder`. To keep pulling from this repo, set `ZM_IMAGE=zoneminderhq/zoneminder` in `.env`.

## Tags

| Tag | What it is |
|---|---|
| `latest`, `1.38`, `1.38.6` | Newest ZoneMinder release |
| `latest-es`, `1.38-es`, `1.38.6-es` | The same, plus the zmeventnotificationNg event server |
| `dev`, `dev-es` | Nightly build of ZoneMinder master. Don't run it on a system you rely on. |
| `latest-el7`, `latest-ubuntu18.04` | **Old, unmaintained.** ZoneMinder 1.36 from 2021, amd64 only, with MySQL inside the container. Kept so existing installs don't break. Don't use them for new installs. |

The current tags, not the 2021 ones, are also on GitHub's registry as `ghcr.io/zoneminder/zoneminder`.

See [zoneminder/zoneminder](https://hub.docker.com/r/zoneminder/zoneminder) for ports, volumes and settings.

## Moving off `latest-el7` or `latest-ubuntu18.04`

The new image doesn't run a database inside the container, so the old `docker run` commands don't work with it. Dump the database from the old container, load it into the compose stack's MariaDB, and point the `events` volume at your old events directory. The schema upgrades to 1.38 on first start. Steps: [Upgrading from the old images](https://github.com/ZoneMinder/zmdockerfiles#upgrading-from-the-old-images).

## Help

- Questions: [ZoneMinder forums](https://forums.zoneminder.com/)
- Bugs in the image: [GitHub issues](https://github.com/ZoneMinder/zmdockerfiles/issues)
