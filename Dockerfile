# syntax=docker/dockerfile:1

FROM docker.io/nixos/nix:latest AS builder

WORKDIR /build

COPY . .

# Build the poller explicitly. This avoids relying on the flake's default
# package and ensures the image runs the scheduled/polling application.
RUN nix \
    --extra-experimental-features "nix-command flakes" \
    build .#poller

# Collect the complete runtime closure required by poller, including:
RUN mkdir -p /runtime/nix/store \
    && cp -a $(nix-store -qR result) /runtime/nix/store/

# Create directories that must exist in the scratch image.
RUN mkdir -p \
    /runtime/etc/transcriber \
    /runtime/var/lib/transcriber/state \
    /runtime/var/lib/transcriber/output \
    /runtime/tmp \
    && chown -R 65532:65532 \
      /runtime/var/lib/transcriber \
      /runtime/tmp

FROM scratch

COPY --from=builder /runtime/ /
COPY --from=builder /build/result /app

ENV TRANSCRIBER_SOURCES=/etc/transcriber/sources.txt
ENV TRANSCRIBER_STATE_DIR=/var/lib/transcriber/state
ENV TRANSCRIBER_OUTPUT_DIR=/var/lib/transcriber/output
ENV TMPDIR=/tmp

VOLUME ["/var/lib/transcriber"]

USER 65532:65532

ENTRYPOINT ["/app/bin/poller"]