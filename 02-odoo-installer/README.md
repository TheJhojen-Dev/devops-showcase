# odooctl

**Automated, secure installation and deployment of Odoo Community on Linux servers.**

> An interactive installer that turns a multi-step ERP deployment — system
> packages, firewall hardening, Docker Engine, reverse proxy, SSL certificates
> and the full Odoo + PostgreSQL stack — into a single guided workflow.
> Includes an Ansible path for remote deployments over SSH.

*Lee esta guía en [Español](README.es.md).*

![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?logo=gnu-bash&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%20Server-E95420?logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Engine%20%2B%20Compose-2496ED?logo=docker&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-Playbooks-EE0000?logo=ansible&logoColor=white)
![Status](https://img.shields.io/badge/Status-v0.1.0--beta-orange)
![License](https://img.shields.io/badge/License-MIT-green)

> ⚠️ **Early-stage project (v0.1.0-beta).** This tool is under active
> development and may contain bugs or incomplete behavior. It is designed for
> **Ubuntu Server** and requires **root privileges**. Review the disclaimer
> shown by the installer before running it against a machine with valuable
> data — the uninstaller removes containers, images, volumes and firewall
> rules permanently.

---

## The Problem It Solves

Deploying Odoo Community on a bare server is not one task — it is a chain of
ten:

1. Update the system and install base packages
2. Harden the firewall (UFW) — including the trap most people miss: Docker
   silently bypassing UFW rules
3. Install Docker Engine and Compose from the official signed repository
4. Write a `docker-compose.yml` for Odoo + PostgreSQL + Nginx
5. Generate an `.env` with database credentials
6. Configure Nginx as a reverse proxy (HTTP + WebSocket)
7. Request and wire Let's Encrypt certificates
8. Set resource limits and healthchecks
9. Keep the certificates renewed
10. Know how to undo all of it cleanly

Doing this by hand is slow, easy to get wrong, and different on every server.
**odooctl consolidates the entire chain into one interactive menu** — or one
Ansible playbook when the target is a remote host.

It's not a control panel. It's not a SaaS. It's a sharp tool for a specific
job, built with the Unix philosophy: **do one thing and do it well.**

---

## What Does It Actually Do?

| Step | Function | What It Does |
|------|----------|--------------|
| 1 | `scripts/01-install-tools.sh` | Updates repositories, upgrades packages and installs base tools (`curl`, `git`, `gnupg`, etc.) |
| 2 | `scripts/02-firewall.sh` | Hardens UFW: deny-by-default policies, SSH with anti-brute-force limit, ports 80/443, and a `DOCKER-USER` chain so Docker cannot bypass the firewall |
| 3 | `scripts/03-docker.sh` | Installs Docker Engine + Compose from the official repository using a verified GPG keyring |
| 4 | `scripts/04-deploy.sh` | Generates `.env` and Nginx config, optionally requests SSL certs with Certbot, and launches the stack |
| — | `setup.sh` | Interactive menu that chains the four steps with progress bars and confirmations |
| — | `ansible/` | Same deployment as idempotent Ansible playbooks, driven over SSH |
| — | `uninstall.sh` | Reverts everything: stack, Docker, UFW rules and generated files |

---

## Demo

```
  ██▒
  ██████▒   ██████▒  ██████▒   ██████▒  █████▒ ████████▒ ██╗
  ██▒   ██▒ ██▒  ██▒ ██▒   ██▒ ██▒   ██▒ ██▒     ╚═██╔═╝  ██║
  ██▒   ██▒ ██▒  ██▒ ██▒   ██▒ ██▒   ██▒ ██▒       ██║    ██║
  ██████▒   █████▒   ██████▒   ██████▒  █████▒    ██║    █████▒
  ╚═════╝   ╚════╝   ╚═════╝   ╚═════╝  ╚════╝    ╚═╝    ╚════╝

1) Instalación Completa (Paso 1 al 4)
2) Paso 1: Actualizar Sistema y Repositorios
3) Paso 2: Configurar Seguridad y UFW
4) Paso 3: Instalar Docker y Docker Compose
5) Paso 4: Desplegar Stack Odoo
6) Desinstalar / Limpiar entorno
0) Salir

Selecciona una opción [0-6]: 1

==================== AVISO IMPORTANTE ====================
   - Espacio mínimo para instalación inicial: 3.5 GB a 4.5 GB.
   - Espacio recomendado: 5 GB a 10 GB.
   Espacio disponible actualmente en /var/lib: 84 GB
==========================================================

   Progreso: [████████░░░░░░░░░░░░]  40% [/]
```

Before the full install, the tool checks available disk space, **refuses to
continue below 3.5 GB**, and requires an explicit confirmation after a
10-second countdown. Every step runs in the background with a live progress
bar; failures point to a log file in `/tmp/odooctl_*.log`.

---

## What Gets Deployed?

A single Docker Compose stack, isolated on its own network:

| Service | Image | Role |
|---------|-------|------|
| `web` | `odoo:19.0` | Odoo Community, 2 workers, proxied mode |
| `db` | `postgres:16-alpine` | PostgreSQL with healthcheck |
| `nginx` | `nginx:alpine` | Reverse proxy on 80/443, HTTP + WebSocket, CPU/memory limits |
| `certbot` | `certbot/certbot` | Renews certificates automatically every 12 hours |

The Nginx config is generated according to your choice: **SSL mode** proxies
to HTTPS with ACME challenge support; **local mode** serves plain HTTP on
`localhost`. Database credentials are generated randomly into a `.env` file
with `chmod 600`.

---

## Quick Start

### Prerequisites

- **Ubuntu Server** (tested target for this version) with root access
- ~5 GB of free disk space recommended (3.5 GB minimum, enforced)
- Ports **80** and **443** free on the host
- For the Ansible path: SSH access to the target server and Ansible installed

### Installation

```bash
git clone https://github.com/your-username/devops-showcase.git
cd devops-showcase/02-odoo-installer
```

### Interactive usage (local server)

```bash
sudo bash setup.sh
```

Pick **option 1** for the full guided installation, or run steps
individually (2–5). Option 6 uninstalls and cleans the environment.

### Ansible usage (remote deployment over SSH)

The same deployment, expressed as idempotent playbooks — no manual SSH
round-trips, no repeating steps per host:

```bash
cd ansible

# 1. Define your target in inventory.ini (uncomment and edit one line)
#    servidor-odoo ansible_host=203.0.113.10 ansible_user=root ansible_port=22

# 2. Adjust settings in group_vars/odoo_servers.yml
#    odoo_domain, odoo_use_ssl, odoo_certbot_email, odoo_deploy_dir

# 3. Deploy
ansible-playbook deploy.yml

# 4. Revert everything
ansible-playbook uninstall.yml
```

The `deploy.yml` playbook chains four roles in order — `system_prep` →
`firewall` → `docker` → `odoo_stack` — and asserts the same 3.5 GB disk
minimum before touching anything.

---

## Project Structure

```
02-odoo-installer/
├── setup.sh                          # Interactive menu (local path)
├── uninstall.sh                      # Full uninstaller (local path)
├── resources/
│   └── banner.sh                     # ASCII banner shown at startup
├── scripts/                          # The four deployment steps
│   ├── 01-install-tools.sh           # System update + base packages
│   ├── 02-firewall.sh                # UFW hardening + DOCKER-USER chain
│   ├── 03-docker.sh                  # Docker Engine via official repo
│   └── 04-deploy.sh                  # .env, Nginx, Certbot, stack launch
├── ansible/                          # Remote path (SSH)
│   ├── ansible.cfg
│   ├── deploy.yml                    # Playbook: roles in sequence
│   ├── uninstall.yml                 # Playbook: full revert
│   ├── inventory.ini                 # Target hosts
│   ├── group_vars/
│   │   └── odoo_servers.yml          # Domain, SSL, deploy dir, credentials
│   └── roles/
│       ├── system_prep/tasks/main.yml
│       ├── firewall/tasks/main.yml
│       ├── docker/tasks/main.yml
│       └── odoo_stack/
│           ├── tasks/main.yml
│           └── templates/            # Compose, .env, Nginx (HTTP/SSL)
└── docker/
    ├── docker-compose.yml            # Stack definition
    └── nginx/
        └── default.conf              # Reverse proxy template
```

**Separation of concerns:**
- `scripts/` contains the imperative local workflow (what `setup.sh` chains).
- `ansible/` contains the declarative remote workflow (same result, idempotent).
- `docker/` holds the stack definition used by both paths.

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| **UFW + `DOCKER-USER` chain** | Docker inserts its own iptables rules that silently bypass UFW. Publishing ports would otherwise expose them regardless of your firewall policy. The `DOCKER-USER` chain in `after.rules` closes that gap, and `deny routed` blocks unauthorized forwarding. |
| **Official Docker repo + GPG keyring** | The distro's `docker.io` package is often outdated. odooctl installs from `download.docker.com` with a verified, permission-scoped keyring — the method recommended by Docker itself. |
| **Space guard before install** | A failed deploy on a full disk leaves a half-configured system. The installer measures free space, explains the real requirements (3.5–4.5 GB minimum, 5–10 GB recommended) and blocks below the floor. |
| **Refuses non-interactive runs** | Destructive confirmations (install, uninstall) are refused when no TTY is attached — no accidental `curl … \| bash` executions. |
| **Random credentials, restricted permissions** | `POSTGRES_PASSWORD` is generated from `/dev/urandom` into `.env` with `chmod 600`. The Ansible path uses the `password` lookup instead, so no secret is stored in the repo. |
| **Certbot standalone with validation** | Local domains (`localhost`, `192.168.*`) are rejected up front — Let's Encrypt cannot validate them. Existing certificates are detected and reused. |
| **Healthchecks without curl** | The Odoo slim image ships without `curl`, so the healthcheck uses a tiny inline Python check against `/web/health`. |
| **Progress bars over silent output** | Every step runs in the background with a spinner + progress bar; output goes to `/tmp/odooctl_*.log` so failures are debuggable without flooding the terminal. |

---

## Security Model

- **Deny-by-default:** incoming and routed traffic denied; only outgoing allowed.
- **SSH:** port 22 open with `ufw limit` (anti-brute-force throttling).
- **Web:** only 80/443 exposed, via Nginx — Odoo and PostgreSQL are never published directly.
- **Docker bypass closed:** the `DOCKER-USER` chain prevents containers from routing around UFW.
- **Secrets:** random-generated, never committed, `chmod 600`.
- **Clean revert:** `uninstall.sh` (or `uninstall.yml`) removes the stack, Docker, firewall rules, certificates and generated files — with a explicit warning that Odoo data is lost permanently.

---

## Roadmap

- [ ] Backup and restore commands for Odoo data and PostgreSQL dumps
- [ ] Non-interactive flags (`--all`, `--uninstall`) for cron/scriptable runs
- [ ] Ansible Vault integration for credential management
- [ ] Multi-host inventory support (staging + production)
- [ ] `--check` / dry-run mode for the local installer
- [ ] Email + webhook notifications on deploy result

---

## Author

Built as part of the **[devops-showcase](../README.md)** portfolio —
a collection of DevOps tools designed to solve real infrastructure
problems with clean, maintainable code.
