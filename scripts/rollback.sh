#!/usr/bin/env bash
# ==============================================================================
# Standalone Rollback Script for Blue-Green Deployment
# ==============================================================================
set -euo pipefail

COMPOSE_FILE="docker-compose.blue-green.yml"
NGINX_CONF="nginx/default.conf"

echo "=========================================================="
echo "Initiating Emergency Rollback"
echo "=========================================================="

if grep -q "app-green:8000" "$NGINX_CONF"; then
    ROLLBACK_TO="blue"
else
    ROLLBACK_TO="green"
fi

echo "[INFO] Rolling back active traffic to: $ROLLBACK_TO"

# Ensure the rollback target container is running
docker compose -f "$COMPOSE_FILE" start "app-$ROLLBACK_TO" || \
docker compose -f "$COMPOSE_FILE" up -d "app-$ROLLBACK_TO"

# Update Nginx upstream configuration
cat <<EOF > "$NGINX_CONF"
upstream app_backend {
    server app-$ROLLBACK_TO:8000;
}

server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Hot-reload Nginx
docker exec bg_nginx_proxy nginx -s reload
echo "[SUCCESS] Rollback complete. Live traffic restored to [$ROLLBACK_TO]."
