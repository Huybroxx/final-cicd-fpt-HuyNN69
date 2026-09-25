#!/usr/bin/env bash
# ==============================================================================
# Automated Zero-Downtime Blue-Green Deployment Script
# ==============================================================================
set -euo pipefail

COMPOSE_FILE="docker-compose.blue-green.yml"
NGINX_CONF="nginx/default.conf"
MAX_RETRIES=10
RETRY_INTERVAL=3

echo "=========================================================="
echo "Starting Blue-Green Zero-Downtime Deployment"
echo "=========================================================="

# 1. Determine active environment
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

echo "[INFO] Currently active environment: $CURRENT_COLOR"
echo "[INFO] Deploying new release to target: $TARGET_COLOR (Internal Port: $TARGET_PORT)"

# 2. Build and start target container
echo "[STEP 1] Starting target container app-$TARGET_COLOR..."
docker compose -f "$COMPOSE_FILE" up -d --no-deps --build "app-$TARGET_COLOR"

# 3. Health Check Verification Loop
echo "[STEP 2] Performing health check on target (http://localhost:$TARGET_PORT/health)..."
HEALTHY=false
for i in $(seq 1 $MAX_RETRIES); do
    echo "  -> Check attempt $i/$MAX_RETRIES..."
    RESPONSE=$(curl -s -m 2 "http://localhost:$TARGET_PORT/health" || echo "")
    if echo "$RESPONSE" | grep -q '"status":"ok"'; then
        HEALTHY=true
        echo "  [SUCCESS] Target app-$TARGET_COLOR passed health check!"
        break
    fi
    sleep $RETRY_INTERVAL
done

# 4. Traffic Switch or Rollback
if [ "$HEALTHY" = true ]; then
    echo "[STEP 3] Updating Nginx configuration to point to app-$TARGET_COLOR..."
    cat <<EOF > "$NGINX_CONF"
upstream app_backend {
    server app-$TARGET_COLOR:8000;
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

        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
EOF

    # Ensure Nginx proxy is running
    docker compose -f "$COMPOSE_FILE" up -d nginx

    # Hot reload Nginx worker processes without dropping connections (Zero-Downtime)
    echo "[STEP 4] Hot-reloading Nginx proxy (zero-downtime traffic switch)..."
    docker exec bg_nginx_proxy nginx -s reload

    # Grace period for existing connections to complete
    sleep 3

    # Stop old container
    echo "[STEP 5] Stopping previous environment app-$CURRENT_COLOR..."
    docker stop "bg_app_$CURRENT_COLOR" || true

    echo "=========================================================="
    echo "DEPLOYMENT COMPLETE: Active environment is now [$TARGET_COLOR]"
    echo "Verified at: $(date -u)"
    echo "=========================================================="
    exit 0
else
    echo "=========================================================="
    echo "[ERROR] Health check FAILED for target app-$TARGET_COLOR!"
    echo "[ROLLBACK] Aborting release. Halting unhealthy target container..."
    docker stop "bg_app_$TARGET_COLOR" || true
    echo "[ROLLBACK] Traffic was NEVER switched. Active environment remains [$CURRENT_COLOR]."
    echo "=========================================================="
    exit 1
fi
