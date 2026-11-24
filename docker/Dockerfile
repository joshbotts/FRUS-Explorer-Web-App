# syntax=docker/dockerfile:1
# FRUS Explorer Light: the image (docs/SPEC.md, Deployment > Image).
# Phase 1 builds the server, with the app's data files beside it since session 8 and the browser
# app since session 9; since PLAN's S27b the image holds search by meaning's encoder and its model.
# rclone (runtime options) arrives later.
#   docker build -f docker/Dockerfile -t frus-explorer-light .

ARG SWIFT_IMAGE=swift:6.4-noble
# web/.node-version names the major; ci.yml's web job checks this line.
ARG NODE_IMAGE=node:22-bookworm-slim
ARG RUNTIME_IMAGE=ubuntu:24.04
# Search by meaning's encoder (PLAN's S27b): llama.cpp at the commit the pinned app's
# Scripts/build-llama-xcframework.sh names, LLAMA_COMMIT, the engine its corpus was embedded through;
# EncoderImageTests holds this line to the script's, so a pin move that moves one moves both.
ARG LLAMA_COMMIT=a0e6dc7384edb8f5d927155e1d26c10b4a310e6d
# The model, the file the app's SemanticModelFetcher names, held to the length the app publishes
# (SemanticModelStore.publishedBytes) and to the SHA-256 the bundled index's provenance names
# (provenance.modelFileSHA256), to which EncoderImageTests holds these lines. scripts/fetch-model reads
# them too, as CI fetches the file into the Actions cache.
ARG MODEL_URL=https://github.com/joshbotts/frus-semantic-vectors/releases/download/encoder-2/embeddinggemma-2-Q8_0.gguf
ARG MODEL_BYTES=309855456
ARG MODEL_SHA256=2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135

# Server stage: a release build with the Swift runtime linked in, so the runtime image
# needs no Swift toolchain. It uses SwiftPM's native build system, which SwiftPM marks
# deprecated: with Swift 6.4's default (swiftbuild), --static-swift-stdlib leaves Foundation's
# CoreFoundation and ICU symbols unresolved at link time. Revisit when a Swift release fixes that.
FROM ${SWIFT_IMAGE} AS build
ARG TARGETARCH
# SQLite's headers, and since S20b Argon2's, whose library hashes local accounts' passwords.
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends libsqlite3-dev libargon2-dev \
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

# Parity stage, built only when asked for (--target parity): frus-parity, which the Compose smoke test
# runs over a Standalone server's own index for check 2 (PLAN's S21d). It builds in the server's cache
# mount, so that once the server is built only the parity harness compiles; no image a release ships
# holds it, since the runtime stage below copies nothing from here.
FROM build AS parity
ARG TARGETARCH
RUN --mount=type=cache,id=frus-light-swiftpm-${TARGETARCH},target=/src/.build,sharing=locked \
    swift build -c release --static-swift-stdlib --build-system native --product frus-parity \
 && install -D -m 0755 "$(swift build -c release --static-swift-stdlib --build-system native --show-bin-path)/frus-parity" /usr/local/bin/frus-parity

# Encoder stage (PLAN's S27b): llama.cpp's CPU llama-server, built from source at LLAMA_COMMIT on the
# runtime's own Ubuntu, so that it links the runtime's libraries, for each architecture on its own
# runner. GGML_NATIVE=OFF builds for the architecture, not for the builder's processor: on amd64 SSE4.2,
# AVX, AVX2, FMA, F16C and BMI2, any x86-64 processor since 2013, and on arm64 its baseline. It links
# OpenMP's libgomp, as the plan's dry run built it. Left out: the web UI, which llama.cpp would fetch
# from Hugging Face as it builds, HTTPS, which the encoder on 127.0.0.1 does not speak, and starting
# processes of its own, which its tools and router would. Its licences go with it: llama.cpp's and
# those of the libraries it carries.
FROM ${RUNTIME_IMAGE} AS encoder
ARG LLAMA_COMMIT
RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends ca-certificates git cmake ninja-build g++ \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /llama.cpp
RUN git init -q . \
 && git remote add origin https://github.com/ggml-org/llama.cpp.git \
 && git fetch -q --depth 1 origin "${LLAMA_COMMIT}" \
 && git checkout -q FETCH_HEAD \
 && [ "$(git rev-parse HEAD)" = "${LLAMA_COMMIT}" ]
RUN cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=OFF \
      -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_APP=OFF \
      -DLLAMA_BUILD_UI=OFF -DLLAMA_USE_PREBUILT_UI=OFF -DLLAMA_OPENSSL=OFF -DLLAMA_SUBPROCESS=OFF \
 && cmake --build build --target llama-server -j "$(nproc)" \
 && install -D -m 0755 build/bin/llama-server /out/llama-server \
 && strip /out/llama-server \
 && install -D -m 0644 LICENSE /out/licenses/LICENSE \
 && find licenses vendor -iname 'LICENSE*' -type f | sort | while read -r file; do \
      install -m 0644 "$file" "/out/licenses/$(printf '%s' "$file" | tr / -)"; \
    done \
 && /out/llama-server --version

# The search model's source: empty, so that the stage below fetches the model, unless the build is given a
# folder holding the file as the context of this name, as CI gives the Actions cache's copy:
#   docker build --build-context model-source=<folder> …
FROM scratch AS model-source

# Model stage (PLAN's S27b): EmbeddingGemma 2's GGUF, the app's, from the folder given or else from the
# release the app's fetcher names, through the one redirect GitHub answers a release's file with, from
# github.com to its asset host; held to the length the app publishes and to the bundled index's SHA-256,
# so that a build with any other file fails. Its folder and file have fixed times and modes, so that the
# runtime's layer of it is byte-identical from build to build, and the same on every architecture.
FROM --platform=$BUILDPLATFORM ${RUNTIME_IMAGE} AS model
ARG MODEL_URL
ARG MODEL_BYTES
ARG MODEL_SHA256
RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
RUN --mount=type=bind,from=model-source,target=/given \
    set -eu; \
    name=embeddinggemma-2-Q8_0.gguf; \
    folder=/out/usr/share/frus-light/model; \
    mkdir -p "$folder"; \
    if [ -f "/given/$name" ]; then \
      cp "/given/$name" "$folder/$name"; \
    else \
      curl --fail --silent --show-error --location --max-redirs 1 --proto '=https' --proto-redir '=https' \
        --retry 3 --output "$folder/$name" "$MODEL_URL"; \
    fi; \
    bytes=$(stat -c %s "$folder/$name"); \
    if [ "$bytes" != "$MODEL_BYTES" ]; then \
      echo "$name is $bytes bytes, where the app publishes $MODEL_BYTES" >&2; exit 1; \
    fi; \
    echo "$MODEL_SHA256  $folder/$name" | sha256sum --check --strict; \
    chmod 0444 "$folder/$name"; \
    find /out -type d -exec chmod 0755 {} +; \
    find /out -exec touch --no-dereference --date='2026-10-15 00:00:00 UTC' {} +

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
# the Swift runtime needs, libargon2 for local accounts' passwords (S20b), libcurl for
# FoundationNetworking's URLSession, which the static Swift runtime links dynamically and through which
# a Standalone server downloads its library (S21c), the time zones (S23e), CA certificates and tini.
# Foundation's date formatters read a zone from /usr/share/zoneinfo: without it, a TZ such as
# America/New_York, which the install guide offers for the backup's hour, traps the server in the first
# formatter, as in each of the cross-reference graph's dates; UTC needs no file. tzdata-legacy keeps the
# older names, such as US/Eastern, which Ubuntu 24.04 moved out of tzdata. libgomp1 is OpenMP's runtime,
# which the encoder's llama-server links (PLAN's S27b).
FROM ${RUNTIME_IMAGE}
RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      libsqlite3-0 libxml2 libstdc++6 libargon2-1 libcurl4t64 libgomp1 tzdata tzdata-legacy ca-certificates tini \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid 10001 frus \
 && useradd --uid 10001 --gid 10001 --home-dir /data --no-create-home --shell /usr/sbin/nologin frus \
 && install -d -o 10001 -g 10001 /data /data/volumes
# The search model (PLAN's S27b), in a layer of its own, made apart from the layers below it and
# byte-identical from build to build, so that an install pulls its 310 MB once a model and both
# architectures share it: at the server's default, /usr/share/frus-light/model.
COPY --link --from=model /out/ /
COPY --from=build /out/frus-light /usr/local/bin/frus-light
COPY LICENSE NOTICE /usr/share/doc/frus-light/
# The encoder, which the server starts at the first search by meaning, at its default, with the licences
# of llama.cpp and of the libraries it carries.
COPY --from=encoder /out/llama-server /usr/local/bin/llama-server
COPY --from=encoder /out/licenses/ /usr/share/doc/frus-light/llama.cpp/
# The manifest, the broken-refs index, the indexing resources and the rest, at the server's
# default FRUS_RESOURCES_DIR.
COPY --from=build /out/resources/ /usr/share/frus-light/resources/
# The browser app, at the server's default FRUS_WEB_DIR.
COPY --from=client /web/dist/ /usr/share/frus-light/web/

# The server's version and commit; the version and build of the app whose exports it serves, and
# the index version it serves, which a release names (PLAN's S14g). scripts/release build-args
# prints all but REVISION, as image.yml and CI build with them.
ARG VERSION=0.1.0-dev
ARG REVISION=unknown
ARG APP_VERSION=unknown
ARG APP_BUILD=unknown
ARG INDEX_VERSION=unknown
LABEL org.opencontainers.image.title="FRUS Explorer Light" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.description="Self-hosted web edition of FRUS Explorer" \
      org.opencontainers.image.source="https://github.com/joshbotts/FRUS-Explorer-Web-App" \
      org.opencontainers.image.licenses="Apache-2.0" \
      io.github.joshbotts.frus-explorer.version="${APP_VERSION}" \
      io.github.joshbotts.frus-explorer.build="${APP_BUILD}" \
      io.github.joshbotts.frus-explorer.index-version="${INDEX_VERSION}"

# Everything the server keeps is under /data, owned by the server's user, so a new named
# volume mounted there starts with that ownership; /data/volumes too, so that Import mode's TEI
# mount finds a folder there and Docker makes none of root's in the volume, which a Standalone
# server, keeping its library there (S21c), could not write. The root filesystem can be read-only.
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
