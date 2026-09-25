#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.blue-green.yml"
NGINX_CONF="nginx/default.conf"
MAX_RETRIES=10
RETRY_INTERVAL=3

echo "Starting Blue-Green deployment..."

if grep -q "app-green:8000" "$NGINX_CONF" 2>/dev/null; then
    CURRENT_COLOR="green"
    TARGET_COLOR="blue"
    TARGET_PORT=8001
    CURRENT_PORT=8002
else
    CURRENT_COLOR="blue"
    TARGET_COLOR="green"
    TARGET_PORT=8002
    CURRENT_PORT=8001
fi

echo "Current active: $CURRENT_COLOR, deploying target: $TARGET_COLOR"

docker compose -f "$COMPOSE_FILE" up -d --no-deps --build "app-$TARGET_COLOR"

echo "Verifying target container health on port $TARGET_PORT..."
HEALTHY=false
for i in $(seq 1 $MAX_RETRIES); do
    RESPONSE=$(curl -s -m 2 "http://localhost:$TARGET_PORT/health" || echo "")
    if echo "$RESPONSE" | grep -q '"status":"ok"'; then
        HEALTHY=true
        echo "Target app-$TARGET_COLOR health check passed."
        break
    fi
    sleep $RETRY_INTERVAL
done

if [ "$HEALTHY" = true ]; then
    echo "Switching Nginx traffic to app-$TARGET_COLOR..."
    cat <<EOF > "$NGINX_CONF"
upstream app_backend {
    server app-$TARGET_COLOR:8000;
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

        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
EOF

    docker compose -f "$COMPOSE_FILE" up -d nginx
    sleep 2
    docker exec bg_nginx_proxy nginx -s reload || docker compose -f "$COMPOSE_FILE" restart nginx
    sleep 3

    echo "Stopping previous container app-$CURRENT_COLOR..."
    docker stop "bg_app_$CURRENT_COLOR" || true

    echo "Deployment successful: active environment is now [$TARGET_COLOR]"
    exit 0
else
    echo "Health check failed for app-$TARGET_COLOR. Aborting deployment..."
    docker stop "bg_app_$TARGET_COLOR" || true
    echo "Rollback: traffic remains on [$CURRENT_COLOR]"
    exit 1
fi