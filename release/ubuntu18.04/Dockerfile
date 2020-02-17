FROM ubuntu:18.04
MAINTAINER Peter Gallagher

# Update base packages
RUN apt-get update \
    && apt-get upgrade -y ; \ 
    apt-get install -y --no-install-recommends gnupg ; \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ABE4C7F993453843F0AEB8154D0BF748776FFB04 \
    && echo deb http://ppa.launchpad.net/iconnor/zoneminder-1.32/ubuntu bionic main > /etc/apt/sources.list.d/zoneminder.list \
    && apt-get update ; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y zoneminder \
    && a2enconf zoneminder \
    && a2enmod rewrite cgi; \
    apt-get remove --purge -y $BUILD_PACKAGES $(apt-mark showauto) && rm -rf /var/lib/apt/lists/*;

# Setup Volumes
VOLUME /var/cache/zoneminder/events /var/cache/zoneminder/images /var/lib/mysql /var/log/zm

# Expose http port
EXPOSE 80

# Configure entrypoint
COPY utils/entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
