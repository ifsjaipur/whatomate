# syntax=docker/dockerfile:1

FROM node:18-alpine AS frontend-builder
WORKDIR /build
COPY frontend ./frontend
WORKDIR /build/frontend
RUN npm ci --legacy-peer-deps || npm install --legacy-peer-deps
RUN npm run build
RUN echo "=== FRONTEND BUILD OUTPUT ===" && ls -laR dist/

FROM golang:alpine AS backend-builder
RUN apk add --no-cache git make gcc musl-dev tree
WORKDIR /build

# Copy dependencies first
COPY go.mod go.sum ./
RUN go mod download

# Copy all source
COPY . .

# Show current structure
RUN echo "=== BEFORE FRONTEND COPY ===" && tree -L 3 -I 'vendor|node_modules' || ls -laR

# Remove and replace frontend
RUN rm -rf frontend/dist
COPY --from=frontend-builder /build/frontend/dist ./frontend/dist

# Show structure after copy
RUN echo "=== AFTER FRONTEND COPY ===" && \
    tree -L 3 frontend/ || ls -laR frontend/ && \
    echo "=== CHECKING INDEX.HTML ===" && \
    find . -name "index.html" -type f && \
    echo "=== CONTENT OF EMBED.GO ===" && \
    head -50 internal/frontend/embed.go || cat internal/frontend/embed.go

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -v -o whatomate ./cmd/server

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata curl bash
RUN addgroup -g 1000 appuser && adduser -D -u 1000 -G appuser appuser
WORKDIR /app
COPY --from=backend-builder /build/whatomate ./whatomate
COPY config.example.toml ./config.toml
RUN mkdir -p /app/data /app/logs && \
    chown -R appuser:appuser /app && \
    chmod +x /app/whatomate
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s CMD curl -f http://localhost:8080/ || exit 1
CMD ["./whatomate", "-workers=1"]
