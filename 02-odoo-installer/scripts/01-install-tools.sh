#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/odooctl_sysprep.log"

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

echo -e "\n\e[1;34m[PASO 1/4] Actualizando repositorios y paquetes del sistema...\e[0m"

print_progress 0 " "

run_with_progress 0 25 \
    "Error en apt-get update" \
    apt-get update -y

run_with_progress 25 65 \
    "Error en apt-get upgrade" \
    apt-get upgrade -y

run_with_progress 65 90 \
    "Error instalando dependencias" \
    apt-get install -y --no-install-recommends \
        curl wget git htop ca-certificates gnupg lsb-release

apt-get clean >> "$LOG_FILE" 2>&1
rm -rf /var/lib/apt/lists/*
print_progress 100 "✓"

echo -e "\n\e[1;32m [OK]\e[0m"
echo -e "\e[1;32m[✓] Sistema actualizado correctamente.\e[0m"
