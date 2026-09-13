import os
import sys
import subprocess
import argparse

def check_root():
    if os.geteuid() != 0:
        print("[!] Error: Este script requiere privilegios de administrador. Ejecútalo con 'sudo'.")
        sys.exit(1)

def audit_firewall():
    print("[*] Iniciando auditoría del cortafuegos...")
    try:
        result = subprocess.run(["ufw", "status"], capture_output=True, text=True, check=True)
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
    except Exception:
        pass
    return "unknown"

def analyze_ssh_logs():
    init_system = get_init_system()
    print(f"[*] Sistema de init detectado: {init_system.upper()}")
    print("[*] Analizando intentos fallidos de autenticación SSH...")
    
    failed_attempts = []
    
    # Estrategia 1: Archivo genérico Syslog / Authlog (Debian/Ubuntu/antiX tradicional)
    if os.path.exists("/var/log/auth.log"):
        try:
            with open("/var/log/auth.log", "r") as f:
                failed_attempts = [line.strip() for line in f if "Failed password" in line or "bad password" in line]
        except Exception as e:
            print(f"[!] Error al leer /var/log/auth.log: {e}")
            return

    # Estrategia 2: Entornos estrictos Runit (Socklog o supervisión directa)
    elif init_system == "runit":
        runit_log_paths = [
            "/var/log/socklog/secure/current",
            "/var/log/socklog/auth/current",
            "/var/service/sshd/log/main/current"
        ]
        for path in runit_log_paths:
            if os.path.exists(path):
                try:
                    with open(path, "r") as f:
                        failed_attempts = [line.strip() for line in f if "Failed" in line or "bad" in line]
                    break
                except Exception:
                    continue

    # Estrategia 3: Entornos estrictos Systemd (Journalctl)
    elif init_system == "systemd":
        try:
            result = subprocess.run(
                ["journalctl", "_SYSTEMD_UNIT=ssh.service", "--no-pager", "-n", "50"],
                capture_output=True, text=True, check=True
            )
            failed_attempts = [line for line in result.stdout.splitlines() if "Failed" in line]
        except Exception as e:
            print(f"[!] Error al acceder a journalctl: {e}")
            return

    if failed_attempts:
        print(f"[!] Alerta: Se detectaron {len(failed_attempts)} intentos fallidos de inicio de sesión:")
        for attempt in failed_attempts[-5:]:
            print(f"  -> {attempt}")
    else:
        print("[+] No se detectaron anomalías ni intentos fallidos de inicio de sesión recientes.")

def main():
    check_root()
    
    parser = argparse.ArgumentParser(description="SysGuard CLI - Herramienta de Auditoría y Hardening")
    parser.add_argument("--check-firewall", action="store_true", help="Audita el estado actual de UFW")
    parser.add_argument("--analyze-logs", action="store_true", help="Analiza ataques de fuerza bruta en los logs")
    
    args = parser.parse_args()
    
    if args.check_firewall:
        audit_firewall()
    elif args.analyze_logs:
        analyze_ssh_logs()
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
