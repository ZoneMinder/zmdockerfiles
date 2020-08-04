FROM ubuntu:disco
MAINTAINER Isaac Connor <isaac@zoneminder.com>

# Fix missing locales
ENV LC_ALL="C.UTF-8" LANG="C.UTF-8"

# Skip interactive post-install scripts
ENV DEBIAN_FRONTEND=noninteractive

# Don't install recommends
RUN echo 'apt::install-recommends "false";' > /etc/apt/apt.conf.d/00recommends

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    curl \
    wget \
    gnupg \
    ca-certificates

# Install base toolset
RUN apt-get update && apt-get install -y \
    tzdata \
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
    dh-systemd \
    libdistro-info-perl \
    apache2-dev bzip2 dh-linktree docutils-common \
    ffmpeg fontconfig fontconfig-config fonts-dejavu-core gir1.2-polkit-1.0 \
    libapr1 libapr1-dev libaprutil1 libaprutil1-dev libasound2 libasound2-data \
    libass9 libasyncns0 libavc1394-0 libavcodec-dev libavcodec58 libavdevice-dev \
    libavdevice58 libavfilter-dev libavfilter7 libavformat-dev libavformat58 \
    libswresample-dev libswresample3 libavutil-dev libavutil56 \
    libb-hooks-op-check-perl libbluray2 libbs2b0 libbz2-1.0 libbz2-dev libcaca0 \
    libcairo2 libcdio-cdda2 libcdio-paranoia2 libcdio18 libchromaprint1 \
    libclass-mix-perl libcrypt-eksblowfish-perl libcrypt-rijndael-perl \
    libcurl3-gnutls libcurl4-gnutls-dev libdata-entropy-perl \
    libdata-float-perl libdata-uuid-perl libdate-manip-perl libdatrie1 \
    libdbd-mysql-perl libdbi-perl libdc1394-22 libdevel-callchecker-perl \
    libdrm-amdgpu1 libdrm-common libdrm-nouveau2 libdrm-radeon1 \
    libdrm2 libdynaloader-functions-perl libedit2 libevent-2.1-6 libexpat1 \
    libexpat1-dev libfftw3-double3 libflac8 libflite1 libfontconfig1 \
    libfreetype6 libfribidi0 libgcrypt20-dev libgdk-pixbuf2.0-0 \
    libgdk-pixbuf2.0-common libgl1 libgl1-mesa-dri libglapi-mesa libglib2.0-0 \
    libglib2.0-bin libglib2.0-data libglib2.0-dev libglib2.0-dev-bin libglvnd0 \
    libglx-mesa0 libglx0 libgme0 libgmp-dev libgmpxx4ldbl libgnutls-dane0 \
    libgnutls-openssl27 libgnutls28-dev libgnutls30 libgnutlsxx28 \
    libgpg-error-dev libgraphite2-3 libgsm1 libharfbuzz0b libhttp-lite-perl \
    libidn11 libidn2-0-dev libidn2-dev libiec61883-0 libjack-jackd2-0 libjbig0 \
    libjs-jquery \
    libjs-mootools libjs-sphinxdoc libjs-underscore libldap-2.4-2 libldap-common  \
    libldap2-dev libllvm7 libmp3lame0 libmpg123-0 \
    libmysofa0 libmariadb-dev-compat libmariadb3 libnorm1 libnuma1 libogg0 \
    libopenal-data libopenal1 libopenjp2-7 libopenmpt0 libopus0 libp11-kit-dev \
    libpango-1.0-0 libpangocairo-1.0-0 libpangoft2-1.0-0 libparams-classify-perl \
    libpciaccess0 libpcre16-3 libpcre3-dev libpcre32-3 libpcrecpp0v5 \
    libpgm-5.2-0 libphp-serialization-perl libpixman-1-0 libpng16-16 \
    libpolkit-agent-1-0 libpolkit-gobject-1-0 libpolkit-gobject-1-dev \
    libpostproc-dev libpostproc55 libpulse0 libpython-stdlib \
    libpython2.7-minimal libpython2.7-stdlib libraw1394-11 librsvg2-2 \
    librubberband2 libsamplerate0 libsctp-dev libsctp1 libsdl2-2.0-0 libsensors5 \
    libshine3 libslang2 libsnappy1v5 libsndfile1 libsndio7.0 libsodium23 \
    libsoxr0 libspeex1 libssh-gcrypt-4 libssl-dev libssl1.1 \
    libswscale-dev libswscale5 libsys-mmap-perl libtasn1-6-dev \
    libthai-data libthai0 libtheora0 libtiff5 libtwolame0 libunbound8 \
    libusb-1.0-0 libuuid1 libv4l-0 libv4l-dev libv4l2rds0 libv4lconvert0 \
    libva-drm2 libva-x11-2 libva2 libvdpau1 libvlc-dev libvlc5 libvlccore9 \
    libvorbis0a libvorbisenc2 libvorbisfile3 libvpx5 libwavpack1 \
    libwayland-client0 libwayland-cursor0 libwayland-egl1 libwebp6 libwebpmux3 \
    libwrap0 libx11-6 libx11-data libx11-xcb1 libx264-155 libx264-dev \
    libx265-165 libxau6 libxcb-dri2-0 libxcb-dri3-0 libxcb-glx0 libxcb-present0 \
    libxcb-render0 libxcb-shape0 libxcb-shm0 libxcb-sync1 libxcb-xfixes0 libxcb1 \
    libxcursor1 libxdamage1 libxdmcp6 libxext6 libxfixes3 libxi6 libxinerama1 \
    libxkbcommon0 libxrandr2 libxrender1 libxshmfence1 libxss1 libxv1 \
    libxvidcore4 libxxf86vm1 libzmq5 libzvbi-common libzvbi0 mysql-common \
    net-tools nettle-dev pkg-config python python-alabaster python-babel \
    python-babel-localedata python-certifi python-chardet python-docutils \
    python-idna python-imagesize python-jinja2 python-markupsafe python-minimal \
    python-pkg-resources python-pygments python-requests python-roman python-six \
    python-sphinx python-typing python-tz python-urllib3 python2.7 \
    python2.7-minimal python3-distutils python3-lib2to3 sgml-base \
    shared-mime-info sphinx-common tzdata uuid-dev x11-common xkb-data xml-core \
    zlib1g-dev \
    bzip2 libbz2-1.0 libcurl3-gnutls libexpat1 libglib2.0-0 libglib2.0-data \
    libgnutls30 libldap-2.4-2 libpcre3 libssl1.1 shared-mime-info

# Enable sudo without password
RUN echo '%adm ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
