variable "base_url" {
  type    = string
  default = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
}

variable "base_filename" {
  type    = string
  default = "ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
}

variable "assets_dir" {
  type    = string
  default = "assets"
}

variable "dist_dir" {
  type    = string
  default = "dist"
}

variable "out_prefix" {
  type    = string
  default = "ubuntu-24.04-docker"
}

variable "zstd_level" {
  type    = number
  default = 19
}

