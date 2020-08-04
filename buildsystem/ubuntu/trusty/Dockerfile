FROM ubuntu:trusty
MAINTAINER Isaac Connor <isaac@zoneminder.com>

# Fix missing locales
ENV LC_ALL="C.UTF-8" LANG="C.UTF-8"

# Skip interactive post-install scripts
ENV DEBIAN_FRONTEND=noninteractive

# Don't install recommends
RUN echo 'apt::install-recommends "false";' > /etc/apt/apt.conf.d/00recommends

# Enable extra repositories
RUN apt-get update && apt-get install -y --force-yes \
    apt-transport-https \
    curl \
    wget \
    gnupg \
    ca-certificates \
    software-properties-common python-software-properties
#ADD backports.list /etc/apt/sources.list.d/
#ADD preferences /etc/apt/preferences.d/
RUN curl -s https://packagecloud.io/install/repositories/computology/apt-backport/script.deb.sh | bash
RUN apt-get install -y --force-yes apt=1.2.10
RUN curl -s https://packagecloud.io/install/repositories/packpack/backports/script.deb.sh | bash

# Install base toolset
RUN apt-get update && apt-get install -y --force-yes \
    sudo \
    git \
    build-essential \
    cmake \
    gdb \
    ccache \
    devscripts \
    debhelper \
    cdbs \
    fakeroot \
    lintian \
    equivs \
    rpm \
    alien \
    dh-systemd

RUN apt-get update && apt-get install -y --force-yes \
      libdistro-info-perl apache2-dev comerr-dev dh-linktree docutils-common gir1.2-polkit-1.0 \
      krb5-multidev libapr1 libapr1-dev libaprutil1 libaprutil1-dev libasound2 \
      libasound2-data libasyncns0 libavcodec-dev libavcodec54 libavdevice-dev \
      libavdevice53 libavformat-dev libavformat54 libavresample-dev libavresample1 \
      libavutil-dev libavutil52 libbz2-dev libcdio-cdda1 libcdio-paranoia1 \
      libcdio13 libclass-mix-perl libcrypt-eksblowfish-perl libcrypt-rijndael-perl \
      libcurl4-gnutls-dev libdata-entropy-perl libdata-float-perl \
      libdata-uuid-perl libdate-manip-perl libdbd-mysql-perl libdbi-perl \
      libdc1394-22 libelfg0 libexpat1-dev libflac8 libgcrypt11-dev libglib2.0-bin \
      libglib2.0-data libglib2.0-dev libgnutls-dev libgnutlsxx27 libgpg-error-dev \
      libgsm1 libgssrpc4 libhttp-lite-perl libidn11-dev libjack-jackd2-0 \
      libjpeg-turbo8 libjpeg-turbo8-dev libjpeg8 libjpeg8-dev libjs-jquery \
      libjs-mootools libjs-sphinxdoc libjs-underscore libkadm5clnt-mit9 \
      libkadm5srv-mit9 libkdb5-7 libkrb5-dev libldap2-dev libmp3lame0 libmp4v2-2 \
      libmp4v2-dev libmysqlclient-dev libmysqlclient18 libogg0 libopenjpeg2 \
      libopus0 liborc-0.4-0 libp11-kit-dev libparams-classify-perl libpcre3-dev \
      libpcrecpp0 libphp-serialization-perl libpolkit-agent-1-0 \
      libpolkit-gobject-1-0 libpolkit-gobject-1-dev libpq-dev libpq5 \
      libproxy-tools libproxy1 libpulse0 libraw1394-11 librtmp-dev libsamplerate0 \
      libschroedinger-1.0-0 libsctp-dev libsctp1 libsndfile1 libspeex1 \
      libsqlite3-dev libssl-dev libswscale-dev libswscale2 libsys-mmap-perl \
      libsystemd-login0 libtasn1-6-dev libtheora0 libusb-1.0-0 libv4l-0 libv4l-dev \
      libv4l2rds0 libv4lconvert0 libva1 libvlc-dev libvlc5 libvlccore7 libvorbis0a \
      libvorbisenc2 libvpx1 libwrap0 libx11-6 libx11-data libx264-142 libx264-dev \
      libxau6 libxcb1 libxdmcp6 libxext6 libxfixes3 libxvidcore4 mysql-common \
      pkg-config python-docutils python-jinja2 python-markupsafe python-pygments \
      python-roman python-sphinx sgml-base sphinx-common uuid-dev vlc-data \
      xml-core zlib1g-dev

# Enable sudo without password
RUN echo '%adm ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
