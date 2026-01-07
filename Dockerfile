# syntax=docker/dockerfile:1

# ============================================
# Stage 1: Build Frontend
# ============================================
FROM node:18-alpine AS frontend-builder

WORKDIR /build

# Copy only frontend directory
COPY frontend ./frontend

WORKDIR /build/frontend

# Install dependencies
RUN npm ci --legacy-peer-deps || npm install --legacy-peer-deps

# Build frontend (output: /build/frontend/dist)
RUN npm run build

# Verify the build
RUN echo "=== Frontend Build Complete ===" && \
    ls -la dist/ && \
    test -f dist/index.html && echo "✓ index.html exists" || (echo "✗ index.html missing!" && exit 1)

# ============================================
# Stage 2: Build Backend WITH Embedded Frontend
# ============================================
FROM golang:alpine AS backend-builder

# Install build dependencies
RUN apk add --no-cache git make gcc musl-dev

WORKDIR /build

# First, copy go.mod and go.sum for dependency caching
COPY go.mod go.sum ./
RUN go mod download

# Now copy the ENTIRE source code
COPY . .

# CRITICAL: Remove any old frontend/dist and replace with fresh build
RUN rm -rf frontend/dist

# Copy the freshly built frontend from previous stage
COPY --from=frontend-builder /build/frontend/dist ./frontend/dist

# Verify frontend files are in place for embedding
RUN echo "=== Verifying Frontend Before Go Build ===" && \
    ls -la frontend/dist/ && \
    test -f frontend/dist/index.html && echo "✓ Frontend ready for embedding" || (echo "✗ Frontend missing!" && exit 1)

# Build the Go binary (this embeds frontend/dist)
RUN CGO_ENABLED=0 GOOS=linux go build -v \
    -ldflags '-w -s -extldflags "-static"' \
    -o whatomate ./cmd/server

# Verify binary was created
RUN test -f whatomate && echo "✓ Binary built successfully" || (echo "✗ Binary build failed!" && exit 1)

# ============================================
# Stage 3: Final Runtime Image
# ============================================
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata curl bash

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Set working directory
WORKDIR /app

# Copy binary (frontend is embedded inside it)
COPY --from=backend-builder /build/whatomate ./whatomate

# Copy config template
COPY config.example.toml ./config.toml

# Create necessary directories
RUN mkdir -p /app/data /app/logs

# Set permissions
RUN chown -R appuser:appuser /app && \
    chmod +x /app/whatomate

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Run the application
CMD ["./whatomate", "-workers=1"]
```

## **Key Points in This Dockerfile:**

1. **Lines 8-22**: Build frontend completely in isolation
2. **Lines 39-41**: Remove any old dist folder before copying fresh one
3. **Lines 44-46**: Copy fresh frontend build BEFORE Go compilation
4. **Lines 49-52**: Verify files exist before building Go binary
5. **Lines 55-58**: Build Go binary (embeds frontend/dist via go:embed)
6. **Line 77**: Only copy the binary - frontend is embedded inside it

## **Alternative: Check Build Logs**

Can you check the **build logs** (not runtime logs) in Coolify? Look for the section where it says:
```
=== Verifying Frontend Before Go Build ===
