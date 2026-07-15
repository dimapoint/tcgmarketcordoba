# syntax=docker/dockerfile:1

# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder

# Install CA certs and timezone data (needed at runtime for outbound HTTPS)
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /src

# Cache module downloads separately from source so this layer is only
# invalidated when go.mod / go.sum change — not on every source edit.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go/pkg/mod \
    go mod download -x

# Copy source and build a fully static binary.
# TARGETARCH is injected by BuildKit when using `docker build --platform`
# or `docker buildx build`; defaults to the host arch if not set.
ARG TARGETARCH
COPY . .
RUN --mount=type=cache,target=/root/.cache/go/build \
    CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH:-amd64} \
    go build \
      -trimpath \
      -ldflags="-s -w -extldflags '-static'" \
      -o /api \
      ./main.go

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
# busybox:musl provides static wget + sh for healthcheck probes;
# nothing else is carried into scratch.
FROM busybox:musl AS busybox

FROM scratch

# Bring in certs and timezone data from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo                 /usr/share/zoneinfo

# Minimal tools for healthcheck — scratch has no shell or utilities
COPY --from=busybox /bin/wget /bin/wget
COPY --from=busybox /bin/sh   /bin/sh

COPY --from=builder /api /api

# WEB_DIR is set by the full-stack image (root Dockerfile).
# When running the API alone this env var is left unset and
# the server skips the Flutter static-file handler.
ENV PORT=8080

EXPOSE 8080

ENTRYPOINT ["/api"]
