locals {
  build_id  = formatdate("YYYYMMDDhhmmss", timestamp())
  base_path = "${path.root}/${var.assets_dir}/${var.base_filename}"
  out_path  = "${path.root}/${var.dist_dir}/${var.out_prefix}_${local.build_id}_amd64.tar.zst"
}

source "null" "local" {
  communicator = "none"
}

build {
  sources = ["source.null.local"]

  provisioner "shell-local" {
    environment_vars = [
      "BASE_URL=${var.base_url}",
      "BASE_TPL=${local.base_path}",
      "DIST_DIR=${path.root}/${var.dist_dir}",
      "OUT_TPL=${local.out_path}",
      "ZSTD_LEVEL=${var.zstd_level}",
      "ASSETS_DIR=${path.root}/${var.assets_dir}",
    ]

    inline = [
      <<-EOT
      set -euo pipefail

      if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: This build needs root (mount + chroot). Run: sudo packer build ." >&2
        exit 1
      fi

      mkdir -p "$ASSETS_DIR" "$DIST_DIR"

      need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing host tool: $1" >&2; exit 1; }; }
      need tar
      need mount
      need umount
      need chroot
      need mktemp
      need install

      if ! command -v zstd >/dev/null 2>&1; then
        echo "Missing host tool: zstd (provides zstdcat/unzstd). Install it and retry." >&2
        exit 1
      fi

      if [ ! -f "$BASE_TPL" ]; then
        echo "==> Base template missing, downloading to: $BASE_TPL"
        if command -v curl >/dev/null 2>&1; then
          curl -fsSL "$BASE_URL" -o "$BASE_TPL"
        elif command -v wget >/dev/null 2>&1; then
          wget -qO "$BASE_TPL" "$BASE_URL"
        else
          echo "Need curl or wget to download the base template." >&2
          exit 1
        fi
      else
        echo "==> Base template exists: $BASE_TPL"
      fi

      WORKDIR="$(mktemp -d)"
      ROOTFS="$WORKDIR/rootfs"
      mkdir -p "$ROOTFS"

      cleanup() {
        set +e
        # Unmount in reverse order (most nested first)
        mountpoint -q "$ROOTFS/dev/pts" && umount -lf "$ROOTFS/dev/pts"
        mountpoint -q "$ROOTFS/proc"    && umount -lf "$ROOTFS/proc"
        mountpoint -q "$ROOTFS/sys"     && umount -lf "$ROOTFS/sys"
        mountpoint -q "$ROOTFS/dev"     && umount -lf "$ROOTFS/dev"
        rm -rf "$WORKDIR"
      }
      trap cleanup EXIT

      echo "==> Extracting rootfs..."
      if command -v zstdcat >/dev/null 2>&1; then
        zstdcat "$BASE_TPL" | tar -xpf - -C "$ROOTFS"
      elif command -v unzstd >/dev/null 2>&1; then
        unzstd -c "$BASE_TPL" | tar -xpf - -C "$ROOTFS"
      else
        zstd -dc "$BASE_TPL" | tar -xpf - -C "$ROOTFS"
      fi

      echo "==> Mounting for chroot..."
      mount -t proc proc "$ROOTFS/proc"
      mount -t sysfs sys "$ROOTFS/sys"

      # Minimal /dev access for apt (safe bind, not recursive)
      mount --bind /dev "$ROOTFS/dev"

      # PTYs for chrooted commands (prevents apt tools from failing)
      mkdir -p "$ROOTFS/dev/pts"
      mount -t devpts devpts "$ROOTFS/dev/pts" -o gid=5,mode=620

      # DNS inside chroot for apt (avoid symlink issues)
      if [ -f /etc/resolv.conf ]; then
        mkdir -p "$ROOTFS/etc"
        rm -f "$ROOTFS/etc/resolv.conf"
        install -m 0644 /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
      fi

      echo "==> Installing Docker packages inside rootfs (Ubuntu repos)..."
      chroot "$ROOTFS" /usr/bin/env bash -lc '
        set -eux
        export DEBIAN_FRONTEND=noninteractive
        apt update
        apt install -y docker.io docker-buildx docker-compose docker-compose-v2 vim 

        # Enable docker at boot (chroot has no running systemd)
        mkdir -p /etc/systemd/system/multi-user.target.wants /etc/systemd/system/sockets.target.wants || true
        ln -sf /lib/systemd/system/docker.service /etc/systemd/system/multi-user.target.wants/docker.service || true
        ln -sf /lib/systemd/system/docker.socket  /etc/systemd/system/sockets.target.wants/docker.socket || true

        apt autoremove -y
        apt clean
        rm -rf /var/lib/apt/lists/*
        truncate -s 0 /etc/machine-id || true
      '

      echo "==> Unmounting chroot mounts before repack..."
      umount -lf "$ROOTFS/dev/pts" 2>/dev/null || true
      umount -lf "$ROOTFS/proc"    2>/dev/null || true
      umount -lf "$ROOTFS/sys"     2>/dev/null || true
      umount -lf "$ROOTFS/dev"     2>/dev/null || true

      echo "==> Repacking to: $OUT_TPL"
      tar --numeric-owner -C "$ROOTFS" -cpf - . | zstd -T0 -"$ZSTD_LEVEL" -o "$OUT_TPL"

      echo "==> Done."
      ls -lh "$OUT_TPL"
      EOT
    ]
  }
}

