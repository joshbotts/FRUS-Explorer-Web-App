# syntax=docker/dockerfile:1
# FRUS Explorer Light: the image (docs/SPEC.md, Deployment > Image).
# Phase 1 builds the server alone. The encoder stage (phase 4) and the web client (session 9)
# arrive later, as do FRUSExplorer/Resources (the reader, session 8) and rclone (runtime options).
#   docker build -f docker/Dockerfile -t frus-explorer-light .

ARG SWIFT_IMAGE=swift:6.4-noble
ARG RUNTIME_IMAGE=ubuntu:24.04

# Server stage: a release build with the Swift runtime linked in, so the runtime image
# needs no Swift toolchain. It uses SwiftPM's native build system, which SwiftPM marks
# deprecated: with Swift 6.4's default (swiftbuild), --static-swift-stdlib leaves Foundation's
# CoreFoundation and ICU symbols unresolved at link time. Revisit when a Swift release fixes that.
FROM ${SWIFT_IMAGE} AS build
ARG TARGETARCH
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends libsqlite3-dev \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
# The cache mount speeds up local rebuilds; GitHub's runners do not keep it. One per architecture,
# locked, so a two-platform or concurrent build cannot share SwiftPM's build database.
RUN --mount=type=cache,id=frus-light-swiftpm-${TARGETARCH},target=/src/.build,sharing=locked \
    swift build -c release --static-swift-stdlib --build-system native --product FRUSLightServer \
 && install -D -m 0755 "$(swift build -c release --static-swift-stdlib --build-system native --show-bin-path)/FRUSLightServer" /out/frus-light \
 && strip /out/frus-light

# Runtime stage: Ubuntu 24.04's SQLite 3.45.1 (with FTS5), the C++ runtime the Swift runtime
# needs, CA certificates and tini.
FROM ${RUNTIME_IMAGE}
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends libsqlite3-0 libstdc++6 ca-certificates tini \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid 10001 frus \
 && useradd --uid 10001 --gid 10001 --home-dir /data --no-create-home --shell /usr/sbin/nologin frus \
 && install -d -o 10001 -g 10001 /data
COPY --from=build /out/frus-light /usr/local/bin/frus-light
COPY LICENSE /usr/share/doc/frus-light/LICENSE

ARG VERSION=0.1.0-dev
LABEL org.opencontainers.image.title="FRUS Explorer Light" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.description="Self-hosted web edition of FRUS Explorer" \
      org.opencontainers.image.source="https://github.com/joshbotts/FRUS-Explorer-Web-App" \
      org.opencontainers.image.licenses="Apache-2.0"

# Everything the server keeps is under /data, owned by the server's user, so a new named
# volume mounted there starts with that ownership. The root filesystem can be read-only.
USER 10001:10001
ENV FRUS_DATA_DIR=/data \
    FRUS_HOST=0.0.0.0 \
    FRUS_PORT=8080
VOLUME ["/data"]
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/frus-light", "--check-health"]
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/frus-light"]
