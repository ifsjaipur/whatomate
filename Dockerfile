# syntax=docker/dockerfile:1

# ============================================
# Stage 1: Build Frontend
# ============================================
FROM node:18-alpine AS frontend-builder

WORKDIR /app

# Copy frontend directory
COPY frontend ./frontend

WORKDIR /app/frontend

# Install and build
RUN npm ci --legacy-peer-deps || npm install --legacy-peer-deps
RUN npm run build

# Verify
RUN ls -la dist/ && test -f dist/index.html

# ============================================
# Stage 2: Build Backend
# ============================================
FROM golang:alpine AS backend-builder

RUN apk add --no-cache git make gcc musl-dev

WORKDIR /app

# Copy go files first for caching
COPY go.mod go.sum ./
RUN go mod download

# Copy ALL source code
COPY . .

# CRITICAL: The embed directive in internal/frontend/embed.go
# looks for files RELATIVE to that directory
# So we need frontend/dist to be at /app/frontend/dist

# Remove old dist and copy fresh build
RUN rm -rf frontend/dist
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Verify the exact path the embed expects
RUN echo "=== Checking paths for go:embed ===" && \
    ls -la frontend/dist/ && \
    test -f frontend/dist/index.html && echo "✓ Files ready"

# Build (embed directive will include frontend/dist)
RUN CGO_ENABLED=0 GOOS=linux go build -v \
    -ldflags '-w -s' \
    -o whatomate ./cmd/server

# ============================================
# Stage 3: Runtime
# ============================================
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata curl bash
RUN addgroup -g 1000 appuser && adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# Binary only (frontend is embedded)
COPY --from=backend-builder /app/whatomate ./whatomate
COPY config.example.toml ./config.toml

RUN mkdir -p /app/data /app/logs && \
    chown -R appuser:appuser /app && \
    chmod +x /app/whatomate

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["./whatomate", "-workers=1"]
