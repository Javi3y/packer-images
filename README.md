# Packer Templates

This repository contains **Packer-based templates** for building reusable **virtualization images**.

Right now it only includes **CT/LXC rootfs templates**, but the plan is to add **VM templates** later (e.g., cloud-init ready images, golden images, etc.).

## Why this exists

I had to install Docker in **a lot of containers**, over and over again, and I got tired of repeating the same steps.

So instead of doing it manually every time, I turned the process into a **repeatable build** that outputs a ready-to-use template artifact.

---

## What this repo does (today)

- Builds **reusable templates** for virtualization/container platforms
- Runs **locally** (no remote hypervisor required, no SSH)
- Produces `.tar.zst` artifacts for CT/LXC rootfs templates
- Keeps a cached copy of base templates under `assets/`

---

## Repository structure

- `packer/` → all Packer builds
- `packer/ct/` → CT/LXC templates (**current / only type so far**)
- `packer/vm/` → VM templates (**planned / to be added**)

Each template folder is self-contained with:
- `README.md`
- `template.pkr.hcl`
- `variables.pkr.hcl`
- `versions.pkr.hcl`

---

## Current templates

### 1) Ubuntu 24.04 Docker (CT/LXC)
Path: `packer/ct/ubuntu/24.04/docker`

- Downloads the base Ubuntu 24.04 CT template (if missing)
- Installs Docker packages from Ubuntu repos:
  - `docker.io`
  - `docker-buildx`
  - docker compose tooling
- Enables Docker for boot (no `systemctl start` during build)
- Outputs a ready `.tar.zst` artifact

See details: `packer/ct/ubuntu/24.04/docker/README.md`

---

## Quick start

From the template directory:

```bash
cd packer/ct/ubuntu/24.04/docker
packer fmt .
packer validate .
sudo packer build template.pkr.hcl

```
---

## Thanks

Built with **HashiCorp Packer** — thanks to the Packer team and community.  
https://developer.hashicorp.com/packer
