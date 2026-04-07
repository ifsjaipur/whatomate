#!/bin/sh

cat > /app/config.toml <<EOF
[app]
name = "${APP_NAME:-Whatomate}"
environment = "${APP_ENVIRONMENT:-production}"
debug = ${APP_DEBUG:-false}

[server]
host = "0.0.0.0"
port = ${SERVER_PORT:-8080}

[database]
host = "${DB_HOST:-localhost}"
port = ${DB_PORT:-5432}
user = "${DB_USER:-postgres}"
password = "${DB_PASSWORD:-postgres}"
name = "${DB_NAME:-whatomate}"
ssl_mode = "${DB_SSLMODE:-disable}"

[redis]
host = "${REDIS_HOST:-localhost}"
port = ${REDIS_PORT:-6379}
password = "${REDIS_PASSWORD:-}"
db = ${REDIS_DB:-0}

[jwt]
secret = "${JWT_SECRET:-change-me}"
access_expiry_mins = 15
refresh_expiry_days = 7

[whatsapp]
api_version = "${WHATSAPP_API_VERSION:-v18.0}"
webhook_verify_token = "${WHATSAPP_WEBHOOK_VERIFY_TOKEN:-}"

[ai]
openai_api_key = "${AI_OPENAI_API_KEY:-}"
anthropic_api_key = "${AI_ANTHROPIC_API_KEY:-}"
google_api_key = "${AI_GOOGLE_API_KEY:-}"

[tts]
engine = "piper"
piper_binary = "/usr/local/bin/piper"
piper_model = "/opt/piper/models/en_US-lessac-medium.onnx"
output_dir = "/app/audio"

[storage]
type = "local"
local_path = "./uploads"
EOF

exec ./whatomate server -migrate -config config.toml
