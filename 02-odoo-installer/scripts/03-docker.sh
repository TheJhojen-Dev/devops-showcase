#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/odooctl_docker.log"

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

    for ((i=0; i<filled; i++)); do
        bar="${bar}█"
    done

    for ((i=0; i<empty; i++)); do
        bar="${bar}░"
    done

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

prepare_keyring() {
    mkdir -p /etc/apt/keyrings
    chmod 0755 /etc/apt/keyrings
    rm -f /etc/apt/keyrings/docker.gpg

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
}

add_docker_repository() {
    local os_id
    os_id=$(. /etc/os-release && echo "$ID")

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${os_id} \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
}

enable_docker_services() {
    systemctl daemon-reload
    systemctl enable --now docker.service
    systemctl enable --now containerd.service
}

echo -e "\n\e[1;34m[PASO 3/4] Instalando Docker y Docker Compose Engine...\e[0m"

print_progress 0 " "

run_with_progress 0 20 \
    "Error configurando las llaves GPG de Docker" \
    prepare_keyring

run_with_progress 20 40 \
    "Error al registrar el repositorio de Docker" \
    add_docker_repository

run_with_progress 40 60 \
    "Error actualizando repositorios con fuentes de Docker" \
    apt-get update -y

run_with_progress 60 90 \
    "Error instalando Docker y sus componentes" \
    apt-get install -y --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

run_with_progress 90 100 \
    "Error activando los servicios de Systemd para Docker" \
    enable_docker_services

echo -e "\n\e[1;32m [OK]\e[0m"
echo -e "\e[1;32m[✓] Docker y Docker Compose instalados correctamente.\e[0m"
echo -e "\e[1;37m    → Repositorio oficial configurado de forma segura.\e[0m"
echo -e "\e[1;37m    → Servicios Docker y Containerd iniciados en Systemd.\e[0m"
