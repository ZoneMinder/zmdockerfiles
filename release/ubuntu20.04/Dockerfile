FROM ubuntu:focal
MAINTAINER p0rc0_r0ss0 <https://github.com/p0rc0jet>

ENV LC_ALL="C.UTF-8" LANG="C.UTF-8" DEBIAN_FRONTEND=noninteractive

RUN echo 'apt::install-recommends "false";' > /etc/apt/apt.conf.d/00recommends \
    && apt update && apt upgrade -y \
    && apt install -y --no-install-recommends gnupg apt-transport-https curl wget ca-certificates file \
    && echo "deb https://zmrepo.zoneminder.com/debian/master focal/" > /etc/apt/sources.list.d/zm_focal.list \
    && wget -O - https://zmrepo.zoneminder.com/debian/archive-keyring.gpg | apt-key add - \
    && apt update \
    && apt install -y zoneminder apache2 libapache2-mod-php \
    && a2enconf zoneminder \
    && a2enmod rewrite cgi

VOLUME /var/cache/zoneminder/events /var/cache/zoneminder/images /var/lib/mysql /var/log/zm
EXPOSE 80

COPY patch/skin.css /usr/share/zoneminder/www/skins/classic/css/base/
COPY utils/entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
