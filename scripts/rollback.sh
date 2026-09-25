#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.blue-green.yml"
NGINX_CONF="nginx/default.conf"

if grep -q "app-green:8000" "$NGINX_CONF"; then
    ROLLBACK_TO="blue"
else
    ROLLBACK_TO="green"
fi

echo "Rolling back traffic to: $ROLLBACK_TO"

docker compose -f "$COMPOSE_FILE" start "app-$ROLLBACK_TO" || \
docker compose -f "$COMPOSE_FILE" up -d "app-$ROLLBACK_TO"

cat <<EOF > "$NGINX_CONF"
upstream app_backend {
    server app-$ROLLBACK_TO:8000;
}

server {
    listen 80;
    server_name fuji.io.vn www.fuji.io.vn localhost;

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

docker exec bg_nginx_proxy nginx -s reload
echo "Rollback completed. Live traffic routed to [$ROLLBACK_TO]"