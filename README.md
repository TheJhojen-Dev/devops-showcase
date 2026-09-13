# 🚀 DevOps Engineering Showcase: Enterprise Automation & Infrastructure

![Linux](https://img.shields.io/badge/Linux-antiX%20%2F%20Debian%20%2F%20Ubuntu-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Bash](https://img.shields.io/badge/Bash_Scripting-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardening%20%26%20Compliance-red?style=for-the-badge&logo=shield)
![Status](https://img.shields.io/badge/Status-Active_Development-brightgreen?style=for-the-badge)

¡Bienvenido! Este repositorio no es un espacio de aprendizaje pasivo ni un *roadmap* teórico. Es un **portafolio de ingeniería de producción** diseñado para demostrar capacidades reales en la resolución de problemas de infraestructura, automatización avanzada, seguridad y cultura DevOps. 

Cada directorio contiene herramientas, scripts y arquitecturas completamente funcionales, concebidas bajo estándares de nivel empresarial para optimizar operaciones, mitigar riesgos y reducir la carga operativa repetitiva (*Toil*).

---

## 🎯 Enfoque del Repositorio

El proyecto está diseñado bajo tres pilares fundamentales:

* **Automatización pragmática:** Sustituir procesos manuales propensos a errores por scripts robustos, portables y mantenibles en Bash y Python.
* **Seguridad desde el diseño (Shift-Left Security):** Implementación de auditoría, hardening y cumplimiento normativo directamente en la infraestructura y contenedores.
* **Optimización de recursos y orquestación:** Soluciones orientadas a mejorar la eficiencia operativa en entornos local, on-premise y producción.

---

## 📂 Estructura del Proyecto

A continuación se detalla la topología de los primeros módulos en desarrollo:

```text
devops-showcase/
├── 01-security-compliance/    # SysGuard CLI: Herramienta interactiva de auditoría y hardening en Linux.
└── 02-erp-containerization/   # Odoo Installer & Proxy: Automatización del despliegue on-premise mediante contenedores.
```

---

## 🛠️ Desglose Técnico de los Módulos

### 1. 01-security-compliance/ — SysGuard CLI (Linux Audit & Hardening)
* **El Problema:** La auditoría manual de seguridad en servidores Linux consume tiempo crítico y suele pasar por alto intentos fallidos de intrusión o configuraciones débiles en el cortafuegos.
* **La Solución:** Una herramienta interactiva en línea de comandos (CLI) desarrollada en Python. Interactúa con el sistema operativo para verificar en tiempo real el estado de las reglas del firewall (UFW/iptables), analiza registros de autenticación (`auth.log`) buscando anomalías por fuerza bruta vía SSH, y genera reportes estructurados listos para auditorías.
* **Impacto:** Demuestra dominio en scripting avanzado con Python, gestión de procesos de Linux, análisis de seguridad en tiempo real y empaquetado de utilidades de administración de sistemas.

### 2. 02-erp-containerization/ — Enterprise Odoo Installer & Proxy
* **El Problema:** Desplegar sistemas ERP complejos de manera local u on-premise requiere configuraciones manuales minuciosas de dependencias, bases de datos relacionales, cortafuegos y proxies inversos, lo que aumenta el riesgo de fallos en el aprovisionamiento.
* **La Solución:** Un instalador y orquestador CLI automatizado basado en Bash y Docker. Aprovisiona de extremo a extremo un ecosistema Odoo vanilla junto a PostgreSQL. Aísla el tráfico mediante un proxy inverso con Nginx (puertos 80/443), optimiza las imágenes mediante construcción multi-etapa (*multi-stage builds*), aplica reglas en el cortafuegos del host y programa tareas de mantenimiento automatizadas.
* **Impacto:** Evidencia la habilidad para orquestar aplicaciones empresariales monolíticas, gestionar redes de contenedores aisladas, automatizar despliegues on-premise y administrar la seguridad perimetral del servidor.

---

## 🧰 Stack Tecnológico Destacado

| Categoría | Tecnologías / Herramientas |
| :--- | :--- |
| **Sistemas Operativos** | Linux (Debian, Ubuntu, antiX) |
| **Scripting & Lenguajes** | Python 3, Bash Shell |
| **Contenedores & Redes** | Docker, Docker Compose, Nginx (Reverse Proxy) |
| **Seguridad & Auditoría** | UFW / iptables, SSH Hardening, Log Analysis (auth.log) |
| **Bases de Datos** | PostgreSQL |

---

## ⚡ Cómo Explorar los Módulos

Cada módulo cuenta con su propio archivo `README.md` detallado, guías de instalación, requisitos previos y ejemplos de ejecución.

1. Navega al directorio del módulo correspondiente:
   ```bash
   cd 01-security-compliance
   # o
   cd 02-erp-containerization
   ```
2. Revisa la documentación interna para ejecutar la herramienta o desplegar la infraestructura.

---

💼 **Autor:** Jhojen — Cloud DevOps & Systems Automation
