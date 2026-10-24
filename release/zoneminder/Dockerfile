# ZoneMinder from the zmrepo packages, supervised by s6-overlay.
#
# Base image: Debian stable by default, so the image follows each new Debian release. Ubuntu LTS
# also works, because zmrepo builds for it too: --build-arg BASE_IMAGE=ubuntu:26.04
#
# Targets:
#   zm     ZoneMinder + Apache + go2rtc                      (default)
#   zm-es  zm + zmeventnotificationNg event server and ML hook (ML runs in a pyzm-serve container)
#
# Build from the repo root:
#   docker build -t zoneminder release/zoneminder                                   # newest release
#   docker build --target zm-es -t zoneminder:es release/zoneminder
#   docker build --build-arg ZM_CHANNEL=master -t zoneminder:dev release/zoneminder  # nightly dev build
#   docker build --build-arg ZM_VERSION=1.38.6+trixie1 -t zoneminder:1.38.6 release/zoneminder     # pinned
#
# ZM_CHANNEL=release finds the newest release-1.x channel on zmrepo at build time (see zm-version.sh),
# so a new minor release needs no edit here. Docker caches that lookup with the layer: use
# --no-cache, or pass ZM_VERSION explicitly as CI does, to pick up a newer package.
#
# See docker-compose.yaml in the repo root for a full stack with MariaDB.

ARG BASE_IMAGE=debian:stable-slim

FROM ${BASE_IMAGE} AS zm

ARG TARGETARCH
# zmrepo channel: release (newest release-1.x), master (nightly), or a directory such as release-1.38
ARG ZM_CHANNEL=release
# Exact zoneminder package version; empty installs the newest in the channel
ARG ZM_VERSION=
ARG S6_OVERLAY_VERSION=3.2.3.2
ARG GO2RTC_VERSION=1.9.14

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_KILL_GRACETIME=20000 \
    S6_VERBOSITY=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Base tools and the zmrepo signing key
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gpg xz-utils \
    && curl -fsSL https://zmrepo.zoneminder.com/debian/archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/zoneminder.gpg \
    && rm -rf /var/lib/apt/lists/*

# s6-overlay
RUN case "${TARGETARCH}" in \
        amd64) s6_arch=x86_64 ;; \
        arm64) s6_arch=aarch64 ;; \
        *) echo "unsupported arch ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && for f in noarch "${s6_arch}"; do \
        curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${f}.tar.xz" \
            | tar -C / -Jxp; \
    done

# go2rtc (ZM 1.38 uses it for WebRTC/MSE live view)
RUN curl -fsSL -o /usr/local/bin/go2rtc \
        "https://github.com/AlexxIT/go2rtc/releases/download/v${GO2RTC_VERSION}/go2rtc_linux_${TARGETARCH}" \
    && chmod 755 /usr/local/bin/go2rtc

# ZoneMinder, Apache + mod_php, DB client, VA-API drivers, mail
COPY zm-version.sh /usr/local/bin/zm-version
RUN codename="$(. /etc/os-release && echo "$VERSION_CODENAME")" \
    && channel="${ZM_CHANNEL}" \
    && if [ -n "${ZM_VERSION}" ] && [ "$channel" = release ]; then channel="release-$(cut -d. -f1,2 <<< "${ZM_VERSION}")"; fi \
    && resolved="$(zm-version "$channel" "$codename" "$(dpkg --print-architecture)")" \
    && channel="$(sed -n 's/^ZM_CHANNEL=//p' <<< "$resolved")" \
    && version="${ZM_VERSION:-$(sed -n 's/^ZM_VERSION=//p' <<< "$resolved")}" \
    && echo "Installing zoneminder ${version} from ${channel}" \
    && echo "deb [signed-by=/usr/share/keyrings/zoneminder.gpg] https://zmrepo.zoneminder.com/debian/${channel} ${codename}/" \
        > /etc/apt/sources.list.d/zoneminder.list \
    && apt-get update \
    && hwaccel="mesa-va-drivers vainfo" \
    && if [ "${TARGETARCH}" = amd64 ]; then hwaccel="${hwaccel} intel-media-va-driver"; fi \
    && apt-get install -y --no-install-recommends \
        "zoneminder=${version}" \
        apache2 libapache2-mod-php \
        mariadb-client \
        msmtp-mta \
        openssl \
        tzdata \
        ${hwaccel} \
    && rm -rf /var/lib/apt/lists/* \
    && a2enconf zoneminder \
    && a2enmod rewrite cgi headers expires proxy proxy_http \
    && a2dismod -f autoindex \
    && rm -f /etc/apache2/conf-enabled/other-vhosts-access-log.conf \
    && sed -i -E "/^\s*(ErrorLog|CustomLog)/d" /etc/apache2/sites-available/000-default.conf

COPY rootfs/ /
RUN a2enconf zm-docker \
    && chmod 755 /etc/s6-overlay/scripts/* /usr/local/bin/zm-healthcheck /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish

EXPOSE 80 8555
VOLUME ["/var/cache/zoneminder", "/var/log/zm", "/config"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD ["/usr/local/bin/zm-healthcheck"]

ENTRYPOINT ["/init"]


FROM zm AS zm-es

ARG ZMES_VERSION=v7.0.34

# install.sh pulls the ES Perl deps from apt and builds /opt/zoneminder/venv with pyzm[ml] + the hook.
# OpenCV comes from Debian (zm_detect.py imports cv2); inference itself happens in pyzm-serve,
# so no models are downloaded here.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git cpanminus make python3 python3-venv python3-opencv \
        libprotocol-websocket-perl libnet-mqtt-simple-perl wget procps \
    && cpanm --notest --quiet Net::WebSocket::Server \
    && git clone --depth 1 --branch "${ZMES_VERSION}" https://github.com/ZoneMinder/zmeventnotificationNg.git /tmp/zmes \
    && cd /tmp/zmes \
    && WEB_OWNER=www-data WEB_GROUP=www-data ./install.sh \
        --install-es --install-hook --install-es-config --install-hook-config \
        --no-download-models --no-install-opencv --no-interactive \
    && mkdir -p /usr/share/zmes-defaults \
    && for f in zmeventnotification.yml secrets.yml objectconfig.yml es_rules.yml; do \
        if [ -f "/etc/zm/$f" ]; then mv "/etc/zm/$f" /usr/share/zmes-defaults/; \
        else cp "/tmp/zmes/${f%.yml}.example.yml" "/usr/share/zmes-defaults/$f" 2>/dev/null \
            || cp "/tmp/zmes/hook/${f%.yml}.example.yml" "/usr/share/zmes-defaults/$f"; fi; \
    done \
    && rm -rf /tmp/zmes /root/.cpanm /var/lib/apt/lists/* \
    && apt-get purge -y git make && apt-get autoremove -y

ENV ZM_ES_ENABLE=1

EXPOSE 9000
