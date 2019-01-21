# zmdockerfiles
This repository contains Docker files used in various ways for the ZoneMinder project.

## Usage

**Note:** Detailled usage instructions for the development and release Dockerfiles are contained within each Dockerfile.

Docker images are published to Docker Hub and can be pulled directly from there e.g.

### CentOS

Using external folders:
```bash
docker run -d -t -p 1080:443 \
    -v /disk/zoneminder/events:/var/lib/zoneminder/events \
    -v /disk/zoneminder/mysql:/var/lib/mysql \
    -v /disk/zoneminder/logs:/var/log/zm \
    --name zoneminder \
    zoneminderhq/zoneminder:latest-el7
```

Using external folders and external MySQL database:

```bash
docker run -d -t -p 1080:443 \
    -e TZ='America/Los_Angeles' \
    -e ZM_DB_USER='zmuser' \
    -e ZM_DB_PASS='zmpassword' \
    -e ZM_DB_NAME='zoneminder_database' \
    -e ZM_DB_HOST='my_central_db_server' \
    -v /disk/zoneminder/events:/var/lib/zoneminder/events \
    -v /disk/zoneminder/logs:/var/log/zm \
    --shm-size="512m" \
    --name zoneminder \
    zoneminderhq/zoneminder:latest-el7
```

### Ubuntu

```bash
docker run -d -t -p 1080:80 \
    -e TZ='Europe/London' \
    -v ~/zoneminder/events:/var/cache/zoneminder/events \
    -v ~/zoneminder/images:/var/cache/zoneminder/images \
    -v ~/zoneminder/mysql:/var/lib/mysql \
    -v ~/zoneminder/logs:/var/log/zm \
    --shm-size="512m" \
    --name zoneminder \
    zoneminderhq/zoneminder:latest-ubuntu18.04
```

## Contributions

Contributions are welcome, but please follow instructions under each subfolder:

- [buildsystem](https://github.com/ZoneMinder/zmdockerfiles/tree/master/buildsystem) - These build zoneminder into packages
- [development](https://github.com/ZoneMinder/zmdockerfiles/tree/master/development) - These run the latest ZoneMinder code.
- [release](https://github.com/ZoneMinder/zmdockerfiles/tree/master/release) - These run the latest ZoneMinder release.
