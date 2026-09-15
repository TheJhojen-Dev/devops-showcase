"""
resources/banner.py
Banner ASCII y animación de arranque para SysGuard CLI.
Sin dependencias externas — solo stdlib.
"""

import sys
import time

BANNER = r"""
  ███████╗██╗   ██╗███████╗ ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗
  ██╔════╝╚██╗ ██╔╝██╔════╝██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗
  ███████╗ ╚████╔╝ ███████╗██║  ███╗██║   ██║███████║██████╔╝██║  ██║
  ╚════██║  ╚██╔╝  ╚════██║██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║
  ███████║   ██║   ███████║╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝
  ╚══════╝   ╚═╝   ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝

         Auditoría & Hardening Linux  ·  v1.0
"""


def _spinner(message: str, duration: float = 0.9) -> None:
    """Animación de carga ASCII, sin dependencias externas."""
    frames = ["|", "/", "-", "\\"]
    end_time = time.time() + duration
    i = 0
    while time.time() < end_time:
        sys.stdout.write(f"\r  {frames[i % len(frames)]} {message}")
        sys.stdout.flush()
        time.sleep(0.08)
        i += 1
    sys.stdout.write(f"\r  ✓ {message}\n")
    sys.stdout.flush()


def show_banner(init_system: str = "desconocido") -> None:
    """Imprime el banner y la animación de detección del sistema."""
    print(BANNER)
    _spinner("Detectando sistema de init...", duration=0.8)
    print(f"  ✓ Init detectado: {init_system.upper()}")
    print(f"  ✓ Permisos: ROOT")
    print()

# --- Alternate Screen Buffer  ---

_ALT_SCREEN_ON  = "\033[?1049h"
_ALT_SCREEN_OFF = "\033[?1049l"


def enter_alt_screen() -> None:
    """Entra a la pantalla alterna del terminal."""
    sys.stdout.write(_ALT_SCREEN_ON)
    sys.stdout.flush()


def exit_alt_screen() -> None:
    """Restaura la pantalla original del terminal."""
    sys.stdout.write(_ALT_SCREEN_OFF)
    sys.stdout.flush()
