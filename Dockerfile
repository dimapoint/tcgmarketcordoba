# syntax=docker/dockerfile:1

# ── Stage 1: build Flutter web ────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-builder

WORKDIR /app

# Cache pub dependencies before copying full source
COPY pubspec.yaml pubspec.lock ./
RUN --mount=type=cache,target=/root/.pub-cache \
    flutter pub get

# Copy source tree and build for web
COPY . .
RUN flutter build web --release --base-href /

# ── Stage 2: build Go API ─────────────────────────────────────────────────────
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS go-builder

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /src

COPY backend/go.mod backend/go.sum ./
RUN --mount=type=cache,target=/root/.cache/go/pkg/mod \
    go mod download

ARG TARGETARCH
COPY backend/ .
RUN --mount=type=cache,target=/root/.cache/go/build \
    CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH:-amd64} \
    go build -trimpath -ldflags="-s -w -extldflags '-static'" -o /api ./main.go

# ── Stage 3: runtime ──────────────────────────────────────────────────────────
# Pull a static busybox so we have /bin/wget for the healthcheck.
# scratch has no shell or tools at all — CMD-SHELL needs at least wget.
FROM busybox:musl AS busybox

FROM scratch

COPY --from=go-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=go-builder /usr/share/zoneinfo                 /usr/share/zoneinfo

# Minimal shell + wget for healthcheck; nothing else from busybox is copied
COPY --from=busybox /bin/wget /bin/wget
COPY --from=busybox /bin/sh   /bin/sh

# API binary
COPY --from=go-builder /api /api

# Flutter web build — served by the Go webapp handler when WEB_DIR is set
COPY --from=flutter-builder /app/build/web /web

ENV PORT=8080
ENV WEB_DIR=/web

EXPOSE 8080

ENTRYPOINT ["/api"]
