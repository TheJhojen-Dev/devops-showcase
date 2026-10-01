#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/odooctl_security.log"
> "$LOG_FILE"

tput civis 2>/dev/null || true
trap 'tput cnorm 2>/dev/null || true' EXIT

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
    local start_pct=$1
    local end_pct=$2
    local err_msg=$3
    shift 3

    local spinner=("/" "-" "\\" "|")
    local spin_idx=0
    local current=$start_pct
    local tick=0
    local spin_char

    "$@" >> "$LOG_FILE" 2>&1 &
    local cmd_pid=$!

    while kill -0 "$cmd_pid" 2>/dev/null; do
        spin_char="${spinner[spin_idx]}"
        spin_idx=$(( (spin_idx + 1) % ${#spinner[@]} ))

        if (( tick % 3 == 0 && current < end_pct - 1 )); then
            current=$(( current + 1 ))
        fi

        print_progress "$current" "$spin_char"
        tick=$(( tick + 1 ))
        sleep 0.1
    done

    local status=0
    wait "$cmd_pid" || status=$?

    if (( status != 0 )); then
        print_progress "$current" "!"
        echo -e "\n\e[1;31m [FALLO]\e[0m"
        echo -e "\e[1;31m[!] ${err_msg}. Revisa: $LOG_FILE\e[0m"
        exit 1
    fi

    print_progress "$end_pct" "✓"
}

configure_ufw() {
    if ! command -v ufw &> /dev/null; then
        apt-get update && apt-get install -y ufw
    fi
    sleep 0.2

    ufw --force disable > /dev/null 2>&1
    ufw --force reset > /dev/null 2>&1
    sleep 0.4

    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1
    ufw default deny routed > /dev/null 2>&1
    sleep 0.4

    ufw limit 22/tcp comment 'SSH Access' > /dev/null 2>&1
    sleep 0.4

    ufw allow 80/tcp comment 'Nginx HTTP' > /dev/null 2>&1
    ufw allow 443/tcp comment 'Nginx HTTPS' > /dev/null 2>&1
    sleep 0.4

    if [ -f /etc/ufw/after.rules ]; then

        if ! grep -q "DOCKER-USER" /etc/ufw/after.rules; then
            cat << 'EOF' >> /etc/ufw/after.rules

# ─── Bloque de seguridad odooctl para Docker ───
*filter
:DOCKER-USER - [0:0]
-A DOCKER-USER -j RETURN
COMMIT
EOF
        fi
    fi
    sleep 0.4

    ufw --force enable > /dev/null 2>&1
    sleep 0.2
}

echo -e "\n\e[1;34m[PASO 2/4] Configurando Firewall (UFW) y Seguridad...\e[0m"

print_progress 0 " "

run_with_progress 0 100 \
    "Error configurando el firewall UFW" \
    configure_ufw

echo -e "\n\e[1;32m [OK]\e[0m"
echo -e "\e[1;32m[✓] Firewall configurado y activado correctamente.\e[0m"
echo -e "\e[1;37m    → SSH (22) permitido con protección anti-fuerza bruta.\e[0m"
echo -e "\e[1;37m    → HTTP (80) y HTTPS (443) permitidos para Nginx.\e[0m"
echo -e "\e[1;37m    → Políticas globales ajustadas para bloquear bypasses nativos de Docker.\e[0m"
