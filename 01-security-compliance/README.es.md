# 🛡️ SysGuard CLI

**Auditoría de seguridad y hardening para servidores Linux, desde la terminal.**

> Una herramienta interactiva que consolida tareas repetitivas de administración
> en un solo flujo de trabajo: firewall, análisis de intrusiones SSH y diagnóstico
> de rendimiento bajo la metodología USE.

*Read this in [English](README.md).*

![Python](https://img.shields.io/badge/Python-3.12+-blue?logo=python&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey?logo=linux)
![CI](https://img.shields.io/badge/CI-ruff%20%2B%20shellcheck-success?logo=githubactions&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

<p align="center">
  <img src="resources/demo.gif" alt="Demo del CLI SysGuard en acción" width="800">
</p>

---

## El problema que resuelve

Cuando administras servidores Linux, hay tres preguntas que te haces todos los días:

1. **¿El firewall está configurado correctamente?**
2. **¿Alguien está intentando entrar por SSH?**
3. **¿El sistema está saturado o hay errores silenciosos?**

Responderlas implica ejecutar entre 5 y 8 comandos distintos cada vez,
recordar rutas de logs que cambian según la distribución, y formatear
la salida a mano. **SysGuard consolida todo eso en un solo CLI interactivo**
con autocompletado, detección automática del sistema de init y reportes
legibles en pantalla.

No es un framework. No es una suite. Es una herramienta afilada para
una tarea concreta, construida con la filosofía Unix: **hacer una cosa y hacerla bien.**

---

## ¿Qué hace exactamente?

| Función | Qué audita | Cómo |
|---------|-----------|------|
| `check-firewall` | Estado del cortafuegos UFW | Consulta `ufw status` y reporta reglas activas |
| `analyze-logs` | Intentos fallidos de autenticación SSH | Lee logs según el init system detectado (runit, systemd o syslog) |
| `metrics-use` | Rendimiento del sistema | Aplica la metodología USE: **U**tilización, **S**aturación, **E**rrores |

### Detección de init system

SysGuard identifica automáticamente si el servidor corre **runit**, **systemd**
o **syslog** clásico, y adapta la lectura de logs en consecuencia. Esto lo hace
portable entre distribuciones como antiX (runit), Debian/Ubuntu (systemd) o
instalaciones minimalistas con syslog.

---

## Demo

```
  ███████╗██╗   ██╗███████╗ ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗
  ██╔════╝╚██╗ ██╔╝██╔════╝██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗
  ███████╗ ╚████╔╝ ███████╗██║  ███╗██║   ██║███████║██████╔╝██║  ██║
  ╚════██║  ╚██╔╝  ╚════██║██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║
  ███████║   ██║   ███████║╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝
  ╚══════╝   ╚═╝   ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝

         Auditoría & Hardening Linux  ·  v1.0

  ✓ Init detectado: RUNIT
  ✓ Permisos: ROOT

============================================================
 SysGuard Interactive CLI - Presiona TAB para ver comandos
============================================================

sysguard > [TAB]
check-firewall  analyze-logs  metrics-use  exit
```

> Al salir (`exit` o `Ctrl+C`), la terminal se restaura completamente,
> sin dejar rastro visual. Mismo comportamiento que `htop` o `vim`.

---

## Inicio rápido

### Requisitos

- Linux con Python 3.12+
- Privilegios de root (necesario para leer logs y consultar el firewall)

### Instalación

```bash
git clone https://github.com/tu-usuario/devops-showcase.git
cd devops-showcase/01-security-compliance

# Entorno virtual (recomendado)
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Ejecución

```bash
# Modo interactivo (menú con autocompletado)
sudo python3 sysguard.py

# Modo flag (ejecución directa, ideal para scripts o cron)
sudo python3 sysguard.py --check-firewall
sudo python3 sysguard.py --analyze-logs
sudo python3 sysguard.py --metrics-use
```

---

## Opciones del menú interactivo

| Comando | Descripción |
|---------|-------------|
| `check-firewall` | Verifica el estado de UFW y lista reglas activas |
| `analyze-logs` | Busca intentos fallidos de SSH en los logs del sistema |
| `metrics-use` | Diagnóstico de rendimiento: disco, RAM, carga, errores de kernel |
| `exit` | Sale del CLI y restaura la terminal |

Navegación: escribe las primeras letras y presiona **TAB** para autocompletar.

---

## Autocompletado en Bash

SysGuard incluye completion nativa para que los flags funcionen con TAB
directamente en la shell:

```bash
# Activar en la sesión actual
source completions/sysguard-completion.sh

# Activar permanentemente
sudo cp completions/sysguard-completion.sh /etc/bash_completion.d/sysguard
```

Después de esto, `sudo sysguard --<TAB>` muestra todas las opciones disponibles.

---

## Estructura del proyecto

```
01-security-compliance/
├── sysguard.py                  # Punto de entrada principal del CLI
├── resources/                   # Paquete de recursos visuales
│   ├── __init__.py
│   └── banner.py               # ASCII art, animación de arranque, alt screen
├── completions/                 # Artefactos de integración con la shell
│   └── sysguard-completion.sh  # Autocompletado para Bash
├── requirements.txt             # Dependencias Python
└── README.md
```

**Separación de concerns:**
- `resources/` contiene solo código Python importable (UI, presentación).
- `completions/` contiene solo artefactos de shell (instalación, integración OS).
- `sysguard.py` es el único punto de entrada y concentra la lógica de auditoría.

---

## Decisiones de diseño

| Decisión | Rationale |
|----------|-----------|
| **Stdlib primero** | `subprocess`, `os`, `argparse` resuelven el 90% del trabajo sin dependencias externas. Solo se agrega `prompt_toolkit` para la UX interactiva. |
| **Detección de init** | Los logs de SSH viven en rutas distintas según el init system. En vez de hardcodear una ruta, SysGuard detecta y adapta. Portable por diseño. |
| **Alternate screen buffer** | La terminal se restaura al salir, como `htop`. Sin scroll residual, sin ruido visual. UX limpia. |
| **Metodología USE** | En vez de volcar métricas crudas, se estructuran bajo Utilización → Saturación → Errores. El operador lee conclusiones, no datos sueltos. |
| **Zero dependencias pesadas** | El proyecto corre en hardware limitado (3 GB RAM, HDD). Cada dependencia se justifica o no entra. |

---

## CI / Calidad de código

Cada push a `main` ejecuta automáticamente:

| Check | Herramienta | Qué valida |
|-------|-------------|-----------|
| Análisis estático Python | `ruff` | Errores de sintaxis, imports sin usar, variables indefinidas, seguridad básica |
| Lint de shell scripts | `shellcheck` | Errores y malas prácticas en `sysguard-completion.sh` |

> El pipeline está definido en `.github/workflows/` en la raíz del repositorio.

---

## Roadmap

- [ ] Exportación de reportes a JSON para integración con otros sistemas
- [ ] Módulo de auditoría de puertos abiertos (`ss -tunlp`)
- [ ] Integración con `fail2ban-client` para estado de baneos activos
- [ ] Soporte para exportar a Excel (reporte ejecutivo)
- [ ] Test suite con `pytest`

---

## Autor

Construido como parte del portafolio **[devops-showcase](../README.md)** —
una colección de herramientas DevOps diseñadas para resolver problemas reales
de infraestructura con código limpio y mantenible.