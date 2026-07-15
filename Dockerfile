# Imagen de producción para Fly.io: binario Go + build web de Flutter.
# El build web se genera ANTES con deploy.ps1 (flutter build web --release
# con API_URL de prod) y acá solo se copia. No pases API_URL como build-arg:
# el Dockerfile no lo usa; va embebido en build/web/assets/.env.

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
COPY build/web /web

ENV WEB_DIR=/web

EXPOSE 8080

ENTRYPOINT ["/api"]