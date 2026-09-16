ARG BUILD_FROM=ghcr.io/home-assistant/base:3.24-2026.08.0
FROM $BUILD_FROM

ENV LANG=C.UTF-8

# Copy script
COPY rootfs /

# Setup base
ARG BUILD_ARCH
ARG CLI_VERSION=5.5.0
RUN \
    # derive BUILD_ARCH for plain docker build without build args
    if [ -z "${BUILD_ARCH}" ]; then \
        case "$(uname -m)" in \
            x86_64) BUILD_ARCH=amd64 ;; \
            aarch64) BUILD_ARCH=aarch64 ;; \
            *) echo "Unsupported architecture: $(uname -m)" && exit 1 ;; \
        esac; \
    fi \
    && curl -Lso /usr/bin/ha "https://github.com/home-assistant/cli/releases/download/${CLI_VERSION}/ha_${BUILD_ARCH}" \
    && chmod a+x /usr/bin/ha \
    && apk add --no-cache \
        samba-client \
        awake \
    && chmod a+x /run.sh

ARG BUILD_VERSION
LABEL \
    io.hass.name="Samba Backup" \
    io.hass.description="Create backups and store them on a Samba share" \
    io.hass.type="app" \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.url="https://github.com/thomasmauerer/hassio-addons/tree/master/samba-backup"

# Run script
CMD [ "/run.sh" ]
