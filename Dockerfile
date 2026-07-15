# syntax=docker/dockerfile:1.7

################################################################################
# Stage 1 - Build Flutter Web
################################################################################

FROM debian:bookworm AS flutter-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_VERSION=3.44.6
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"

RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    xz-utils \
    git \
    ca-certificates \
    zip \
    libglu1-mesa \
 && rm -rf /var/lib/apt/lists/*

# Descargar el SDK oficial de Flutter
RUN curl -L \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    -o flutter.tar.xz

RUN mkdir -p /opt \
 && tar -xf flutter.tar.xz -C /opt \
 && rm flutter.tar.xz

RUN flutter config --no-analytics
RUN flutter doctor -v

WORKDIR /app

# Cache de dependencias
COPY pubspec.yaml .
COPY pubspec.lock .

RUN --mount=type=cache,target=/root/.pub-cache \
    flutter pub get

# Copiar el proyecto
COPY . .

# Build Flutter Web
RUN flutter build web --release --base-href /

################################################################################
# Stage 2 - Build Go API
################################################################################

FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS go-builder

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /src

COPY backend/go.mod backend/go.sum ./

RUN --mount=type=cache,target=/root/.cache/go/pkg/mod \
    go mod download

COPY backend/ .

ARG TARGETARCH

RUN --mount=type=cache,target=/root/.cache/go/build \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=${TARGETARCH:-amd64} \
    go build \
      -trimpath \
      -ldflags="-s -w -extldflags '-static'" \
      -o /api \
      ./main.go

################################################################################
# Stage 3 - Runtime
################################################################################

FROM busybox:musl AS busybox

FROM scratch

COPY --from=go-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=go-builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=busybox /bin/sh /bin/sh
COPY --from=busybox /bin/wget /bin/wget

COPY --from=go-builder /api /api
COPY --from=flutter-builder /app/build/web /web

ENV PORT=8080
ENV WEB_DIR=/web

EXPOSE 8080

ENTRYPOINT ["/api"]