import argparse
import os
import subprocess
import sys


def check_root():
    if os.geteuid() != 0:
        msg = (
            "[!] Error: Este script requiere privilegios de administrador. "
            "Ejecútalo con 'sudo'."
        )
        print(msg)
        sys.exit(1)


def audit_firewall():
    print("[*] Iniciando auditoría del cortafuegos...")
    # S607 Fix: Usar la ruta absoluta /usr/sbin/ufw para mitigar inyecciones
    ufw_path = "/usr/sbin/ufw"
    if not os.path.exists(ufw_path):
        ufw_path = "ufw"  # Fallback si no está en la ruta estándar

    try:
        result = subprocess.run(
            [ufw_path, "status"], capture_output=True, text=True, check=True
        )
        print(result.stdout)
    except FileNotFoundError:
        print("[!] Error: 'ufw' no está instalado en este sistema.")
    except subprocess.CalledProcessError as e:
        print(f"[!] Error al ejecutar ufw: {e.stderr}")


def get_init_system():
    if os.path.exists("/run/runit") or os.path.exists("/etc/runit"):
        return "runit"
    try:
        if os.getpid() == 1:
            with open("/proc/1/comm", "r") as f:
                if "systemd" in f.read():
                    return "systemd"
    except Exception as e:
        # S110 Fix: Evitar pass silencioso registrando el contexto del error
        print(f"[-] No se pudo determinar init vía /proc/1/comm: {e}")
    return "unknown"


def analyze_ssh_logs():
    init_system = get_init_system()
    print(f"[*] Sistema de init detectado: {init_system.upper()}")
    print("[*] Analizando intentos fallidos de autenticación SSH...")

    failed_attempts = []

    if os.path.exists("/var/log/auth.log"):
        try:
            with open("/var/log/auth.log", "r") as f:
                failed_attempts = [
                    line.strip()
                    for line in f
                    if "Failed password" in line or "bad password" in line
                ]
        except Exception as e:
            print(f"[!] Error al leer /var/log/auth.log: {e}")
            return

    elif init_system == "runit":
        runit_log_paths = [
            "/var/log/socklog/secure/current",
            "/var/log/socklog/auth/current",
            "/var/service/sshd/log/main/current",
        ]
        for path in runit_log_paths:
            if os.path.exists(path):
                try:
                    with open(path, "r") as f:
                        failed_attempts = [
                            line.strip()
                            for line in f
                            if "Failed" in line or "bad" in line
                        ]
                    break
                except Exception as err:
                    # S112 Fix: Registrar el fallo de lectura antes de continuar
                    print(f"[-] Saltando ruta de log ilegible {path}: {err}")
                    continue

    elif init_system == "systemd":
        # S607 Fix: Usar la ruta absoluta /usr/bin/journalctl
        jctl_path = "/usr/bin/journalctl"
        try:
            result = subprocess.run(
                [jctl_path, "_SYSTEMD_UNIT=ssh.service", "--no-pager", "-n", "50"],
                capture_output=True,
                text=True,
                check=True,
            )
            failed_attempts = [
                line for line in result.stdout.splitlines() if "Failed" in line
            ]
        except Exception as e:
            print(f"[!] Error al acceder a journalctl: {e}")
            return

    if failed_attempts:
        msg = f"[!] Alerta: Se detectaron {len(failed_attempts)} intentos fallidos:"
        print(msg)
        for attempt in failed_attempts[-5:]:
            print(f"  -> {attempt}")
    else:
        print("[+] No se detectaron anomalías de inicio de sesión recientes.")


def main():
    check_root()

    desc = "SysGuard CLI - Herramienta de Auditoría y Hardening"
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument(
        "--check-firewall",
        action="store_true",
        help="Audita el estado actual de UFW",
    )
    parser.add_argument(
        "--analyze-logs",
        action="store_true",
        help="Analiza ataques de fuerza bruta en los logs",
    )

    args = parser.parse_args()

    if args.check_firewall:
        audit_firewall()
    elif args.analyze_logs:
        analyze_ssh_logs()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
