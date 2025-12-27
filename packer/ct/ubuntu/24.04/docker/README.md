# Ubuntu 24.04 Docker CT Template (Local build)

Builds a Proxmox-compatible CT/LXC rootfs template **locally** (no Proxmox, no SSH).

## What it does
- Downloads the official Proxmox Ubuntu 24.04 CT template if missing
- Installs from Ubuntu repos:
  - docker.io
  - docker-buildx
  - docker-compose-plugin
- Enables Docker for boot (no `systemctl start` during build)
- Outputs a new `.tar.zst` artifact

## Output
- Base cached: `assets/ubuntu-24.04-standard_24.04-2_amd64.tar.zst`
- Built artifact: `dist/ubuntu-24.04-docker_<timestamp>_amd64.tar.zst`

## Build
Run from this directory:

```bash
packer fmt .
packer validate .
sudo packer build template.pkr.hcl

