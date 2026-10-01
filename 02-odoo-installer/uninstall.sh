#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/odooctl_uninstall.log"
> "$LOG_FILE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"

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
        print_progress "$current" "!"
        echo -e "\n\e[1;31m [FALLO]\e[0m"
        echo -e "\e[1;31m[!] ${err_msg}. Revisa: $LOG_FILE\e[0m"
        exit 1
    fi
    print_progress "$end_pct" "✓"
}

if [ "$EUID" -ne 0 ]; then
    echo -e "\e[1;31m[ERROR] Este script debe ejecutarse con privilegios de root (sudo).\e[0m"
    exit 1
fi

if [ ! -t 0 ]; then
    echo -e "\e[1;31m[!] No hay terminal interactiva. No se puede confirmar la desinstalación.\e[0m"
    exit 1
fi

echo -e "\n\e[1;33m==================== AVISO IMPORTANTE ====================\e[0m"
echo -e "\e[1;33m Esta operación revertirá la instalación de odooctl:\e[0m"
echo ""
echo "   Se eliminarán:"
echo "     • Contenedores, imágenes y volúmenes del stack Odoo"
echo "     • Docker Engine y sus componentes"
echo "     • Reglas y configuración de UFW"
echo "     • Certificados SSL generados por Certbot"
echo "     • Archivos generados (.env, configs de nginx)"
echo ""
echo -e "\e[1;31m   ⚠  Los datos de Odoo y PostgreSQL se perderán permanentemente.\e[0m"
echo -e "\e[1;33m=========================================================\e[0m"
echo ""

read -rp "¿Deseas continuar con la desinstalación completa? [s/N]: " answer || answer="n"
case "$answer" in
    [sS]|[sS][iI]|[yY]|[yY][eE][sS]) ;;
    *)
        echo -e "\n\e[1;32mDesinstalación cancelada.\e[0m"
        exit 0
        ;;
esac

tput civis 2>/dev/null || true

echo -e "\n\e[1;34m[PASO 1/4] Deteniendo y eliminando stack de Odoo...\e[0m"
print_progress 0 " "

remove_stack() {
    if [ -f "$DOCKER_DIR/docker-compose.yml" ]; then
        cd "$DOCKER_DIR"
        docker compose down --volumes --remove-orphans 2>/dev/null || true
        docker compose rm -fsv 2>/dev/null || true
    fi

    local images=("odoo:19.0" "nginx:alpine" "postgres:16-alpine" "certbot/certbot")
    for img in "${images[@]}"; do
        docker rmi "$img" 2>/dev/null || true
    done

    docker system prune -f 2>/dev/null || true
}

run_with_progress 0 25 \
    "Error eliminando el stack de Docker Compose" \
    remove_stack

echo -e "\n\e[1;32m [OK]\e[0m"

echo -e "\n\e[1;34m[PASO 2/4] Desinstalando Docker Engine y componentes...\e[0m"
print_progress 25 " "

remove_docker() {
    systemctl stop docker.service 2>/dev/null || true
    systemctl stop containerd.service 2>/dev/null || true
    systemctl disable docker.service 2>/dev/null || true
    systemctl disable containerd.service 2>/dev/null || true

    apt-get purge -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>/dev/null || true

    apt-get autoremove -y 2>/dev/null || true

    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.gpg

    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
}

run_with_progress 25 55 \
    "Error desinstalando Docker" \
    remove_docker

echo -e "\n\e[1;32m [OK]\e[0m"

echo -e "\n\e[1;34m[PASO 3/4] Revirtiendo configuración de UFW...\e[0m"
print_progress 55 " "

revert_ufw() {
    if command -v ufw &> /dev/null; then
        ufw --force disable > /dev/null 2>&1
        ufw --force reset > /dev/null 2>&1
    fi

    if [ -f /etc/ufw/after.rules ]; then
        sed -i '/# ─── Bloque de seguridad odooctl para Docker ───/,/^COMMIT$/d' \
            /etc/ufw/after.rules 2>/dev/null || true
    fi
}

run_with_progress 55 80 \
    "Error revirtiendo la configuración de UFW" \
    revert_ufw

echo -e "\n\e[1;32m [OK]\e[0m"

echo -e "\n\e[1;34m[PASO 4/4] Limpiando archivos generados...\e[0m"
print_progress 80 " "

cleanup_files() {
    rm -rf "$DOCKER_DIR/certbot"
    rm -f "$DOCKER_DIR/.env"
    rm -f /tmp/odooctl_sysprep.log
    rm -f /tmp/odooctl_security.log
    rm -f /tmp/odooctl_docker.log
    rm -f /tmp/odooctl_deploy.log
    rm -f /tmp/odooctl_uninstall.log
}

run_with_progress 80 100 \
    "Error limpiando archivos generados" \
    cleanup_files

echo -e "\n\e[1;32m [OK]\e[0m"

echo ""
echo -e "\e[1;32m[✓] Desinstalación completada.\e[0m"
echo -e "\e[1;37m    → Stack Odoo eliminado (contenedores, volúmenes, imágenes).\e[0m"
echo -e "\e[1;37m    → Docker Engine y componentes desinstalados.\e[0m"
echo -e "\e[1;37m    → UFW desactivado y reglas reiniciadas.\e[0m"
echo -e "\e[1;37m    → Archivos generados (.env, certbot, logs) limpiados.\e[0m"
echo ""
echo -e "\e[1;33m[!] Nota: Los paquetes base del sistema (curl, wget, git, etc.)\e[0m"
echo -e "\e[1;33m    no fueron removidos ya que podrían ser usados por otros programas.\e[0m"
