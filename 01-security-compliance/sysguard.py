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

def main():
    check_root()
    
    parser = argparse.ArgumentParser(description="SysGuard CLI - Herramienta de Auditoría y Hardening")
    parser.add_file = parser.add_argument("--check-firewall", action="store_true", help="Audita el estado actual de UFW")
    
    args = parser.parse_args()
    
    if args.check_firewall:
        audit_firewall()
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
