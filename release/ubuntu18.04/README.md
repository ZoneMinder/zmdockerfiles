# Usage

The Docker images are available from the Docker Hub e.g.

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

Once the container is running you will need to browse to http://hostname:port/zm to access the Zoneminder interface.
