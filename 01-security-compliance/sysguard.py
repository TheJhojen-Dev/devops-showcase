import argparse
import os
import shutil
import subprocess
import sys

# 1. Ajustar sys.path ANTES de importar paquetes internos
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from resources.banner import (
    show_banner,
    enter_alt_screen,
    exit_alt_screen,
)

try:
    from prompt_toolkit import prompt
    from prompt_toolkit.completion import WordCompleter
except ImportError:
    prompt = None


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
    ufw_path = shutil.which("ufw")
    if not ufw_path:
        print("[!] Error: 'ufw' no está instalado en este sistema.")
        return

    try:
        result = subprocess.run(
            [ufw_path, "status"], capture_output=True, text=True, check=True
        )
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"[!] Error al ejecutar ufw: {e.stderr}")


def get_init_system():
    if os.path.exists("/run/runit") or os.path.exists("/etc/runit"):
        return "runit"
    try:
        if os.path.exists("/proc/1/comm"):
            with open("/proc/1/comm", "r") as f:
                if "systemd" in f.read():
                    return "systemd"
    except Exception as e:
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
                    print(f"[-] Saltando ruta de log ilegible {path}: {err}")
                    continue

    elif init_system == "systemd":
        jctl_path = shutil.which("journalctl") or "/usr/bin/journalctl"
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


def analyze_performance_use():
    print("[*] Ejecutando diagnóstico de rendimiento (Metodología USE)...")
    print("-" * 60)

    # 1. UTILIZACIÓN (Uso de disco y memoria)
    print("[U] UTILIZACIÓN:")
    try:
        df = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, check=True)
        disk_line = df.stdout.splitlines()[1].split()
        print(f"  -> Espacio en Disco (/): {disk_line[2]} usado ({disk_line[3]} libre)")
        
        with open("/proc/meminfo", "r") as f:
            memdata = {}
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    memdata[parts[0].strip()] = int(parts[1].split()[0])
            
            total = memdata.get("MemTotal", 1)
            available = memdata.get("MemAvailable", memdata.get("MemFree", 0))
            used_pct = round(((total - available) / total) * 100, 2)
            print(f"  -> Memoria RAM: {used_pct}% en uso real")
    except Exception as e:
        print(f"  [!] Fallo al calcular utilización: {e}")

    # 2. SATURACIÓN (Cola de procesos esperando por CPU)
    print("\n[S] SATURACIÓN:")
    try:
        with open("/proc/loadavg", "r") as f:
            load = f.read().split()
            print(f"  -> Carga promedio (1 min, 5 min, 15 min): {load[0]}, {load[1]}, {load[2]}")
            print(f"  -> Cola de procesos activos: {load[3]}")
    except Exception as e:
        print(f"  [!] Fallo al calcular saturación: {e}")

    # 3. ERRORES (Mensajes críticos del Kernel/Hardware)
    print("\n[E] ERRORES (Mensajes de error recientes en dmesg):")
    try:
        dmesg = subprocess.run(["dmesg", "-l", "err,crit,alert"], capture_output=True, text=True, check=True)
        errors = dmesg.stdout.splitlines()
        if errors:
            for err in errors[-3:]:
                print(f"  -> {err}")
        else:
            print("  [+] No se registran errores críticos recientes en el Kernel.")
    except Exception as e:
        print(f"  [!] Fallo al consultar dmesg: {e}")
    print("-" * 60)


def execute_action(action):
    if action == "check-firewall":
        audit_firewall()
    elif action == "analyze-logs":
        analyze_ssh_logs()
    elif action == "metrics-use":
        analyze_performance_use()
    elif action == "exit":
        print("[*] Saliendo de SysGuard CLI.")
        sys.exit(0)


def run_interactive_menu():
    if not prompt:
        print("[!] Error: 'prompt_toolkit' no está instalado. "
              "Ejecuta 'pip install -r requirements.txt'")
        sys.exit(1)

    enter_alt_screen()
    try:
        init_system = get_init_system()
        show_banner(init_system)

        actions_completer = WordCompleter(
            ["check-firewall", "analyze-logs", "metrics-use", "exit"],
            ignore_case=True,
        )

        print("=" * 60)
        print(" SysGuard Interactive CLI - Presiona TAB para ver comandos")
        print("=" * 60)

        while True:
            try:
                user_input = prompt(
                    "sysguard > ", completer=actions_completer
                ).strip()
                if user_input:
                    execute_action(user_input)
            except (KeyboardInterrupt, EOFError):
                print("\n[*] Saliendo de SysGuard CLI.")
                break
    finally:
        exit_alt_screen()


def main():
    check_root()

    desc = "SysGuard CLI - Herramienta de Auditoría y Hardening"
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument("--check-firewall", action="store_true")
    parser.add_argument("--analyze-logs", action="store_true")
    parser.add_argument("--metrics-use", action="store_true")

    if len(sys.argv) > 1:
        args = parser.parse_args()
        if args.check_firewall:
            audit_firewall()
        elif args.analyze_logs:
            analyze_ssh_logs()
        elif args.metrics_use:
            analyze_performance_use()
        else:
            parser.print_help()
    else:
        run_interactive_menu()


if __name__ == "__main__":
    main()
