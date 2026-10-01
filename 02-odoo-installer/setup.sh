#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo -e "\e[1;31m[ERROR] Este script debe ejecutarse con privilegios de root (sudo).\e[0m"
    exit 1
fi

show_banner() {
    if [ -f "$SCRIPT_DIR/resources/banner.sh" ]; then
        bash "$SCRIPT_DIR/resources/banner.sh"
    fi
}

flush_stdin() {
    [ -t 0 ] || return 0

    local discard

    # shellcheck disable=SC2034
    while read -r -t 0.2 -n 1024 discard; do
        :
    done
}

show_install_disclaimer() {
    if [ ! -t 0 ]; then
        echo -e "\e[1;31m[!] No hay terminal interactiva. No se puede confirmar la instalación.\e[0m"
        return 1
    fi

    local target="/var/lib"
    [ -d "$target" ] || target="/"

    local avail_kb avail_gb

    avail_kb=$( { df -Pk "$target" | awk 'NR==2 {print $4}'; } 2>/dev/null || true)
    avail_kb=${avail_kb:-0}

    if ! [[ "$avail_kb" =~ ^[0-9]+$ ]]; then
        avail_kb=0
    fi

    avail_gb=$(( avail_kb / 1024 / 1024 ))

    echo -e "\n\e[1;33m==================== AVISO IMPORTANTE ====================\e[0m"
    echo -e "\e[1;33m Antes de continuar con la instalación completa de Odoo:\e[0m"
    echo ""
    echo "   - Espacio mínimo para instalación inicial:"
    echo "     3.5 GB a 4.5 GB."
    echo ""
    echo "   - Espacio recomendado:"
    echo "     5 GB a 10 GB."
    echo ""
    echo "   - El espacio recomendado incluye:"
    echo "     imágenes Docker, bases de datos, respaldos,"
    echo "     logs, actualizaciones y datos propios de Odoo."
    echo ""
    echo -e "   Espacio disponible actualmente en \e[1;37m${target}\e[0m: \e[1;37m${avail_gb} GB\e[0m"
    echo ""
    echo -e "\e[1;31m   Si cuentas con menos del mínimo recomendado, la instalación puede fallar.\e[0m"
    echo -e "\e[1;33m=========================================================\e[0m"

    if (( avail_kb < 3500 * 1024 )); then
        echo -e "\n\e[1;31m[!] No hay espacio suficiente para continuar con la instalación.\e[0m"
        return 1
    fi

    local i
    for ((i=10; i>0; i--)); do
        printf "\r   \e[1;36m⏳  Espera %2d segundo(s) para poder confirmar...\e[0m" "$i"
        sleep 1
    done

    printf "\r\033[K"

    flush_stdin

    local answer=""
    read -rp "¿Deseas continuar con la instalación completa? [s/N]: " answer || answer="n"

    case "$answer" in
        [sS]|[sS][iI]|[yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

show_menu() {
    echo "1) Instalación Completa (Paso 1 al 4)"
    echo "2) Paso 1: Actualizar Sistema y Repositorios"
    echo "3) Paso 2: Configurar Seguridad y UFW"
    echo "4) Paso 3: Instalar Docker y Docker Compose"
    echo "5) Paso 4: Desplegar Stack Odoo"
    echo "6) Desinstalar / Limpiar entorno"
    echo "0) Salir"
    echo ""
    echo -e "\e[38;2;156;69;133m---------------------------------------------\e[1;37m"

    read -rp "Selecciona una opción [0-6]: " OPTION || OPTION=0
}

show_banner

while true; do
    show_menu

    case "$OPTION" in
        1)
            if show_install_disclaimer; then
                echo -e "\n\e[1;33m[+] Iniciando instalación completa...\e[0m"

                bash "$SCRIPT_DIR/scripts/01-install-tools.sh"
                bash "$SCRIPT_DIR/scripts/02-firewall.sh"
                bash "$SCRIPT_DIR/scripts/03-docker.sh"
                bash "$SCRIPT_DIR/scripts/04-deploy.sh"

                break
            else
                echo -e "\n\e[1;31m[!] Instalación cancelada o no confirmada.\e[0m"
            fi
            ;;

        2)
            bash "$SCRIPT_DIR/scripts/01-install-tools.sh"
            ;;

        3)
            bash "$SCRIPT_DIR/scripts/02-firewall.sh"
            ;;

        4)
            bash "$SCRIPT_DIR/scripts/03-docker.sh"
            ;;

        5)
            bash "$SCRIPT_DIR/scripts/04-deploy.sh"
            ;;

        6)
            if [ -f "$SCRIPT_DIR/uninstall.sh" ]; then
                bash "$SCRIPT_DIR/uninstall.sh"
            else
                echo -e "\e[1;31m[!] El script uninstall.sh no existe aún.\e[0m"
            fi
            ;;

        0)
            echo -e "\n\e[1;32mSaliendo de odooctl...\e[0m"
            exit 0
            ;;

        *)
            echo -e "\n\e[1;31m[!] Opción inválida. Intenta nuevamente.\e[0m"
            ;;
    esac

    echo ""
done
