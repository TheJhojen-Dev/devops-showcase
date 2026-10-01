#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/odooctl_deploy.log"
> "$LOG_FILE"

tput civis 2>/dev/null || true
trap 'tput cnorm 2>/dev/null || true' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker"

print_progress() {
    local target_pct=$1
    local spin_char=${2:-" "}
    local filled=$(( target_pct / 5 ))
    local empty=$(( 20 - filled ))
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    printf "\r   Progreso: [%s] %3d%% [%s] " "$bar" "$target_pct" "$spin_char"
}

run_with_progress() {
    local start_pct=$1 end_pct=$2 err_msg=$3; shift 3
    local spinner=("/" "-" "\\" "|") spin_idx=0 current=$start_pct tick=0 spin_char
    "$@" >> "$LOG_FILE" 2>&1 &
    local cmd_pid=$!
    while kill -0 "$cmd_pid" 2>/dev/null; do
        spin_char="${spinner[spin_idx]}"
        spin_idx=$(( (spin_idx + 1) % ${#spinner[@]} ))
        if (( tick % 3 == 0 && current < end_pct - 1 )); then current=$(( current + 1 )); fi
        print_progress "$current" "$spin_char"
        tick=$(( tick + 1 )); sleep 0.1
    done
    local status=0; wait "$cmd_pid" || status=$?
    if (( status != 0 )); then
        print_progress "$current" "!"; echo -e "\n\e[1;31m [FALLO]\e[0m"
        echo -e "\e[1;31m[!] ${err_msg}. Revisa: $LOG_FILE\e[0m"; exit 1
    fi
    print_progress "$end_pct" "✓"
}

prepare_environment() {
    mkdir -p "$DOCKER_DIR/certbot/conf" "$DOCKER_DIR/certbot/www"
    if [ ! -f "$DOCKER_DIR/.env" ]; then
        local auto_pass
        auto_pass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
        echo "POSTGRES_PASSWORD=${auto_pass}" > "$DOCKER_DIR/.env"
        chmod 600 "$DOCKER_DIR/.env"
    fi
}

generate_nginx_config() {
    if [ "$USE_SSL" = true ]; then
        cat << EOF > "$DOCKER_DIR/nginx/default.conf"
upstream odoo { server web:8069; }
upstream odoo_websocket { server web:8072; }

server {
    listen 80; listen [::]:80; server_name $DOMAIN;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://\$host\$request_uri; }
}

server {
    listen 443 ssl; listen [::]:443 ssl; server_name $DOMAIN;
    ssl_certificate /etc/letsencrypt/live/odoo_server/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/odoo_server/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3; ssl_ciphers HIGH:!aNULL:!MD5;

    client_max_body_size 100M;
    proxy_read_timeout 720s; proxy_connect_timeout 720s; proxy_send_timeout 720s;
    proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto \$scheme;

    location / { proxy_pass http://odoo; proxy_redirect off; }
    location /websocket {
        proxy_pass http://odoo_websocket; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade";
    }
    location ~* /web/static/ { proxy_cache_valid 200 60m; expires 8d; proxy_pass http://odoo; }
}
EOF
    else
        cat << 'EOF' > "$DOCKER_DIR/nginx/default.conf"
upstream odoo { server web:8069; }
upstream odoo_websocket { server web:8072; }

server {
    listen 80; listen [::]:80; server_name _;
    client_max_body_size 100M;
    proxy_read_timeout 720s; proxy_connect_timeout 720s; proxy_send_timeout 720s;
    proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto $scheme;

    location / { proxy_pass http://odoo; proxy_redirect off; }
    location /websocket {
        proxy_pass http://odoo_websocket; proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade";
    }
}
EOF
    fi
}

launch_stack() {
    cd "$DOCKER_DIR"
    docker compose up -d
}

echo -e "\n\e[1;34m[PASO 4/4] Inicializando Despliegue de Infraestructura y SSL...\e[0m"

if ss -tuln | grep -qE ':(80|443) '; then
    echo -e "\n\e[1;31m[ERROR] Los puertos 80 o 443 ya están ocupados.\e[0m"
    exit 1
fi

tput cnorm 2>/dev/null || true
echo -e "\n\e[1;33m¿Deseas configurar SSL (HTTPS) automatizado con Let's Encrypt? [s/N]:\e[0m"
read -r ssl_answer || ssl_answer="n"

USE_SSL=false
DOMAIN="localhost"
EMAIL="admin@localhost.local"

if [[ "$ssl_answer" =~ ^([sS]|[sS][iI]|[yY]|[yY][eE][sS])$ ]]; then
    USE_SSL=true
    read -rp "   Dominio público: " DOMAIN
    read -rp "   Correo para alertas: " EMAIL
    DOMAIN=$(echo "$DOMAIN" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

    if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
        echo -e "\e[1;31m[ERROR] Dominio y correo son obligatorios.\e[0m"; exit 1
    fi
    if [[ "$DOMAIN" == "localhost" || "$DOMAIN" =~ ^192\.168\. ]]; then
        echo -e "\e[1;31m[ERROR] Let's Encrypt no valida dominios locales.\e[0m"; exit 1
    fi
fi

tput civis 2>/dev/null || true
print_progress 0 " "

run_with_progress 0 40 "Error preparando entorno" prepare_environment

if [ "$USE_SSL" = true ]; then
    tput cnorm 2>/dev/null || true
    echo -e "\n\n\e[1;36m[~] Validando dominio con Let's Encrypt...\e[0m"
    cd "$DOCKER_DIR"
    if [ ! -d "$DOCKER_DIR/certbot/conf/live/odoo_server" ]; then
        if ! docker run --rm -p 80:80 \
          -v "$DOCKER_DIR/certbot/conf:/etc/letsencrypt" \
          -v "$DOCKER_DIR/certbot/www:/var/www/certbot" \
          certbot/certbot certonly --standalone \
          --cert-name odoo_server -d "$DOMAIN" --email "$EMAIL" --agree-tos --no-eff-email; then
            echo -e "\e[1;31m[FALLO] Certbot falló. Verifica DNS y puerto 80 libre.\e[0m"; exit 1
        fi
    else
        echo "[+] Certificados SSL existentes detectados."
    fi
    tput civis 2>/dev/null || true
fi

print_progress 70 "✓"

generate_nginx_config

run_with_progress 70 100 "Error levantando Docker Compose" launch_stack

cd "$DOCKER_DIR" && docker compose restart nginx >> "$LOG_FILE" 2>&1 || true

echo -e "\n\e[1;32m[✓] Stack desplegado con éxito.\e[0m"
if [ "$USE_SSL" = true ]; then
    echo -e "\e[1;37m    → Acceso seguro: \e[1;36mhttps://${DOMAIN}\e[0m"
else
    echo -e "\e[1;37m    → Acceso local: \e[1;36mhttp://localhost\e[0m"
fi
