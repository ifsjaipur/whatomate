# =========================
# Frontend build
# =========================
FROM node:18-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --legacy-peer-deps
COPY frontend ./
RUN npm run build
RUN test -f dist/index.html

# =========================
# Backend build
# =========================
FROM golang:1.24.5-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist
RUN test -f frontend/dist/index.html

RUN CGO_ENABLED=0 GOOS=linux go build -o whatomate ./cmd/server

# =========================
# Runtime
# =========================
FROM alpine:3.19
WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /app/whatomate .
EXPOSE 8080
CMD ["./whatomate"]
