# syntax=docker/dockerfile:1

# Stage 1: Build Frontend
FROM node:18-alpine AS frontend-builder

WORKDIR /frontend

# Copy frontend package files
COPY frontend/package*.json ./

# Install dependencies
RUN npm ci --legacy-peer-deps || npm install --legacy-peer-deps

# Copy frontend source
COPY frontend/ ./

# Build frontend (creates /frontend/dist)
RUN npm run build

# Verify build output
RUN ls -la /frontend/dist || echo "Frontend build failed"

# Stage 2: Build Backend
FROM golang:1.21-alpine AS backend-builder

# Install build dependencies
RUN apk add --no-cache git make gcc musl-dev

WORKDIR /app

# Download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo \
    -ldflags '-w -s -extldflags "-static"' \
    -o whatomate ./cmd/server

# Stage 3: Final Runtime Image
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata curl bash

# Create app user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# Copy backend binary
COPY --from=backend-builder /app/whatomate ./whatomate

# Copy frontend build
COPY --from=frontend-builder /frontend/dist ./frontend/dist

# Copy config template
COPY config.example.toml ./config.toml

# Create directories
RUN mkdir -p /app/data /app/logs && \
    chown -R appuser:appuser /app && \
    chmod +x /app/whatomate

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Start application with embedded worker
CMD ["./whatomate", "-workers=1"]
