# ── Stage 1: build ──────────────────────────────────────────────────────────
FROM golang:1.26-alpine AS builder

# Install only what is needed for CGO-disabled builds (ca-certs for TLS roots)
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Leverage Docker layer cache: only re-download modules when go.mod/go.sum change
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source and build a fully-static binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
      -trimpath \
      -ldflags="-s -w" \
      -o /out/api \
      .

# ── Stage 2: run ────────────────────────────────────────────────────────────
# scratch = zero OS attack surface; only the compiled binary + TLS roots
FROM scratch

# Pull in TLS CA certificates and timezone data from the builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Run as a non-root UID (no /etc/passwd in scratch — use numeric UID directly)
USER 65534:65534

COPY --from=builder /out/api /api

EXPOSE 8080

ENTRYPOINT ["/api"]
