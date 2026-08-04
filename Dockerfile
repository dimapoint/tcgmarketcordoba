# Imagen de producción para Fly.io: binario Go + build web de Flutter.
# Auto-contenido: el build web se genera acá adentro, así el deploy funciona
# igual desde deploy.ps1, la UI web de Fly o CI (el contexto git no trae
# build/web ni .env, ambos gitignoreados).

# ── Stage 0: build web de Flutter ────────────────────────────────────────────
# No existe imagen Docker oficial de Flutter (Google solo distribuye el SDK),
# así que se instala de la forma soportada: clonando flutter/flutter en el tag
# exacto — la misma versión que se usa en dev local.
FROM debian:stable-slim AS webbuilder

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git curl ca-certificates unzip xz-utils zip \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch 3.44.6 https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:$PATH"
# Descarga el Dart SDK y los artefactos web una sola vez, cacheado como layer.
RUN flutter --version && flutter precache --web

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
# .env es un asset bundleado (pubspec.yaml) y gitignoreado: se genera acá con
# los valores públicos de prod. API_URL = mismo origen; el client ID de Google
# es público por diseño (OAuth). No hay secretos en esta imagen.
# ARGs con default para el deploy actual (Railway); overridable con --build-arg
# para otros hosts (p.ej. Fly: --build-arg API_URL=https://tcgmarketcordoba.fly.dev).
ARG API_URL=https://tcgmarketcordoba.up.railway.app
ARG GOOGLE_CLIENT_ID=184679876511-l6647cep8tj76meiru5mq7grdc9l5ljf.apps.googleusercontent.com
RUN printf 'API_URL=%s\nGOOGLE_CLIENT_ID=%s\n' "$API_URL" "$GOOGLE_CLIENT_ID" > .env \
 && flutter build web --release

# ── Stage 1: build del backend ───────────────────────────────────────────────
FROM golang:1.26-alpine AS builder

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

COPY backend/go.mod backend/go.sum ./
RUN go mod download && go mod verify

COPY backend/ .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/api .

# ── Stage 2: run ─────────────────────────────────────────────────────────────
FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

USER 65534:65534

COPY --from=builder /out/api /api
COPY --from=webbuilder /app/build/web /web

ENV WEB_DIR=/web

EXPOSE 8080

ENTRYPOINT ["/api"]
