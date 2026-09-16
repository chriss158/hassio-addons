#!/bin/bash
# Local multi-arch build via Docker BuildKit (legacy homeassistant/amd64-builder is retired)
set -e

cd "$(dirname "$0")"

VERSION=$(sed -n 's/^version: *//p' config.yaml)

declare -A PLATFORMS=([aarch64]=linux/arm64 [amd64]=linux/amd64)

for arch in "${!PLATFORMS[@]}"; do
    docker buildx build \
        --platform "${PLATFORMS[$arch]}" \
        --build-arg BUILD_ARCH="$arch" \
        --build-arg BUILD_VERSION="$VERSION" \
        --tag "thomasmauerer/samba-backup-${arch}:${VERSION}" \
        --load .
done
