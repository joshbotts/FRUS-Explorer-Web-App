# syntax=docker/dockerfile:1
# FRUS Explorer Light: the image (docs/SPEC.md, Deployment > Image).
# Phase 1 builds the server, with the app's data files beside it since session 8 and the browser
# app since session 9. The encoder stage (phase 4) and rclone (runtime options) arrive later.
#   docker build -f docker/Dockerfile -t frus-explorer-light .

ARG SWIFT_IMAGE=swift:6.4-noble
# web/.node-version names the major; ci.yml's web job checks this line.
ARG NODE_IMAGE=node:22-bookworm-slim
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
# What SwiftPM reads, which checks every target's path, tests included; so an edit to the browser
# app leaves this stage cached.
COPY Package.swift Package.resolved ./
COPY Sources/ Sources/
COPY Tests/ Tests/
COPY upstream/ upstream/
# The cache mount speeds up local rebuilds; GitHub's runners do not keep it. One per architecture,
# locked, so a two-platform or concurrent build cannot share SwiftPM's build database.
RUN --mount=type=cache,id=frus-light-swiftpm-${TARGETARCH},target=/src/.build,sharing=locked \
    swift build -c release --static-swift-stdlib --build-system native --product FRUSLightServer \
 && install -D -m 0755 "$(swift build -c release --static-swift-stdlib --build-system native --show-bin-path)/FRUSLightServer" /out/frus-light \
 && strip /out/frus-light
# The app's data files from the pinned commit, whole, as SPEC ships them. Copied here, so their
# modes can be made readable by the server's user whatever the checkout's umask was.
RUN cp -R upstream/FRUS-Explorer/FRUSExplorer/Resources /out/resources \
 && chmod -R a+rX /out/resources

# Client stage: Node runs the Vite production build of the browser app (SPEC, Deployment > Image).
# Its output is the same on every architecture, so it runs on the builder's own, even when the
# image is built for another.
FROM --platform=$BUILDPLATFORM ${NODE_IMAGE} AS client
WORKDIR /web
COPY web/package.json web/package-lock.json web/.npmrc ./
RUN --mount=type=cache,id=frus-light-npm,target=/root/.npm,sharing=locked npm ci --no-audit --no-fund
COPY web/ ./
RUN npm run build && chmod -R a+rX dist

# Runtime stage: Ubuntu 24.04's SQLite 3.45.1 (with FTS5), libxml2 for FoundationXML, whose parser
# FRUSCoreKit reads TEI with and which the static Swift runtime links dynamically, the C++ runtime
# the Swift runtime needs, CA certificates and tini.
FROM ${RUNTIME_IMAGE}
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends libsqlite3-0 libxml2 libstdc++6 ca-certificates tini \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid 10001 frus \
 && useradd --uid 10001 --gid 10001 --home-dir /data --no-create-home --shell /usr/sbin/nologin frus \
 && install -d -o 10001 -g 10001 /data
COPY --from=build /out/frus-light /usr/local/bin/frus-light
COPY LICENSE /usr/share/doc/frus-light/LICENSE
# The manifest, the broken-refs index, the indexing resources and the rest, at the server's
# default FRUS_RESOURCES_DIR.
COPY --from=build /out/resources/ /usr/share/frus-light/resources/
# The browser app, at the server's default FRUS_WEB_DIR.
COPY --from=client /web/dist/ /usr/share/frus-light/web/

ARG VERSION=0.1.0-dev
ARG REVISION=unknown
LABEL org.opencontainers.image.title="FRUS Explorer Light" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.description="Self-hosted web edition of FRUS Explorer" \
      org.opencontainers.image.source="https://github.com/joshbotts/FRUS-Explorer-Web-App" \
      org.opencontainers.image.licenses="Apache-2.0"

# Everything the server keeps is under /data, owned by the server's user, so a new named
# volume mounted there starts with that ownership. The root filesystem can be read-only.
# Two malloc arenas: the reader parses each volume on whichever thread is free, and glibc's
# default of eight arenas a CPU keeps the freed parses. Reading across the 16 largest volumes eight
# times levelled off at about 170 MB with two, where the default passed 300 MB in three.
USER 10001:10001
ENV FRUS_DATA_DIR=/data \
    FRUS_HOST=0.0.0.0 \
    FRUS_PORT=8080 \
    MALLOC_ARENA_MAX=2
VOLUME ["/data"]
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/frus-light", "--check-health"]
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/frus-light"]
