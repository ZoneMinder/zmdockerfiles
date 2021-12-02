# Zoneminder
Based on ubuntu:focal minimal image. Only vital packages and dependencies added (which still grew package from 77MB to 700+MB).

## Release notes
- Added patched `skin.css` to get rid of "font not found" problem for good.
- Release is intended to work with external MySQL only no internal MySQL server installed.
- Dockerfile has been optimized to reduce number of container layers.
- Version deployed through `docker-compose` exposes port 80 and can work standalone or with nginx reverse proxy.

### A drop of lyrics
I've been using Zoneminder for a long time and came up with conclusion that it is better to have separate mysql server for it. Because of this there is separate mysql container with no ports exposed outside, just to own network.

## Getting started
Can be deployed in few easy steps

### Build
Yeah, manual labour :)
```bash
mkdir -p /usr/src/zm_focal/patch
wget https://raw.githubusercontent.com/p0rc0jet/zmdockerfiles/master/release/ubuntu20.04/patch/skin.css -P /usr/src/zm_focal/patch
wget https://raw.githubusercontent.com/p0rc0jet/zmdockerfiles/master/release/ubuntu20.04/Dockerfile -P /usr/src/zm_focal
cd /usr/src/zm_focal
docker build /usr/src/zm_focal -f Dockerfile -t zm_focal_min
```
On success go to next step.

### Compose and up
I'll assume that MySQL container is up and running with name `zm_db`. 

#### docker-compose.yml
```yaml
version: '3.5'

services:

  zm_focal:
    image: zm_focal_min
    container_name: zm_focal
    #restart: unless-stopped
    env_file:
      - zm.env
    volumes:
      - /mnt/zm/zoneminder:/var/cache/zoneminder:rw
      - /mnt/zm/logs:/var/log/zm
      - /mnt/zm/logs:/var/log/zoneminder
      - /dev/dri:/dev/dri
    shm_size: "512mb"
    privileged: false
    environment:
      - TZ=Asia/Tbilisi
      - PUID=99
      - PGID=100
      - MULTI_PORT_START=0
      - MULTI_PORT_END=0
      - VIRTUAL_HOST=zm.domain.local
    ports:
      - "80:80"
    networks:
      - zm

networks:
  zm:
    name: zm
    driver: bridge
```

#### zm.env
```bash
ZM_DB_USER=zm
ZM_DB_PASS=this_is_one_long_password_here
ZM_DB_NAME=zm
ZM_DB_HOST=zm_db
```

Finally
```bash
docker-compose up -d
```

### Connect
http://<your ip or hostname>/zm


