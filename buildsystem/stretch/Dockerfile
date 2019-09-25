FROM debian:stretch
MAINTAINER ISaac Connor <isaac@zoneminder.com>

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
    ca-certificates
#ADD backports.list /etc/apt/sources.list.d/
#ADD preferences /etc/apt/preferences.d/
#RUN curl -s https://packagecloud.io/install/repositories/packpack/backports/script.deb.sh | bash

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
    dh-systemd \
    libdistro-info-perl \
    apache2-dev bzip2 default-libmysqlclient-dev dh-linktree docutils-common \
    ffmpeg fontconfig fontconfig-config fonts-dejavu-core \
    gir1.2-glib-2.0 gir1.2-polkit-1.0 libavcodec-dev libavdevice-dev \
    libavfilter-dev libavformat-dev libavresample-dev libavutil-dev libbz2-dev \
    libclass-mix-perl libcrypt-eksblowfish-perl libcrypt-rijndael-perl \
    libcurl4-gnutls-dev libdata-entropy-perl libdata-float-perl \
    libdata-uuid-perl libdate-manip-perl libdbd-mysql-perl libdbi-perl \
    libencode-locale-perl libfile-listing-perl libgcrypt20-dev \
    libgirepository-1.0-1 libglib2.0-bin libglib2.0-data libglib2.0-dev \
    libgmp-dev libgmpxx4ldbl libgnutls-dane0 libgnutls-openssl27 libgnutls28-dev \
    libgnutlsxx28 libgpg-error-dev libhtml-tree-perl libhttp-cookies-perl \
    libhttp-date-perl libhttp-lite-perl libhttp-message-perl \
    libhttp-negotiate-perl libidn11-dev libio-html-perl libjpeg62-turbo \
    libjpeg62-turbo-dev libjs-jquery libjs-mootools libjs-sphinxdoc \ \
    libjs-underscore liblwp-mediatypes-perl liblwp-protocol-https-perl \
    libmp4v2-2 libmp4v2-dev libnet-http-perl libp11-kit-dev \
    libparams-classify-perl libpcre16-3 libpcre3-dev libpcre32-3 libpcrecpp0v5 \
    libphp-serialization-perl libpolkit-agent-1-0 libpolkit-gobject-1-0 \
    libpolkit-gobject-1-dev libpostproc-dev libpython-stdlib \
    libpython2.7-minimal libpython2.7-stdlib libssl-dev libswresample-dev \
    libswscale-dev libsys-mmap-perl libtasn1-6-dev libunbound2 libv4l-0 \ \
    libv4l-dev libv4l2rds0 libv4lconvert0 libvlc-dev libvlc5 libvlccore9 \
    libwww-perl libwww-robotrules-perl libx264-dev net-tools nettle-dev \
    pkg-config python python-alabaster python-babel python-babel-localedata \
    python-docutils python-imagesize python-jinja2 python-markupsafe \
    python-minimal python-pkg-resources python-pygments python-roman python-six \
    python-sphinx python-tz python2.7 python2.7-minimal sphinx-common 

# Enable sudo without password
RUN echo '%adm ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
