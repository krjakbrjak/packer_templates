packer {
  required_plugins {
    vagrant = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vagrant"
    }
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "username" {
  type = string
  default = "packer"
}

variable "password" {
  type = string
  default = "packer"
}

variable "accelerator" {
  type = string
  default = "kvm"
}

variable "machine" {
  type = string
  default = "q35"
}

variable "vm_name" {
  type = string
  default = "cloudubuntu"
}

variable "iso_checksum" {
  type = string
  default = "file:https://cloud-images.ubuntu.com/releases/25.04/release/SHA256SUMS"
}

variable "qemu_arch" {
  type = string
  default = "x86_64"
}

variable "qemu_dir" {
  type = string
  default = "/usr/bin"
}

variable "qemu_ssh_port" {
  type = number
  default = 52222
}

locals {
  iso_url     = "https://cloud-images.ubuntu.com/releases/25.04/release/ubuntu-25.04-server-cloudimg-${var.qemu_arch}.img"
  qemu_binary = var.qemu_arch == "arm64" ? "qemu-system-aarch64" : "qemu-system-x86_64"
  # Architecture-specific arguments
  arm64_args      = var.qemu_arch == "arm64" ? [["-bios", "edk2-aarch64-code.fd"]] : []
  build_timestamp = timestamp()
  build_directory = "build/${local.build_timestamp}"
  vagrant_box     = "${local.build_directory}/${var.vm_name}.box"
  vagrant_arch    = var.qemu_arch == "arm64" ? "aarch64" : var.qemu_arch
  vagrant_file    = <<EOF
Vagrant.configure(2) do |config|
  config.vm.box = "${var.vm_name}.box"
  config.vm.provider :qemu do |qe, override|
    override.ssh.username = "${var.username}"
    override.ssh.password = "${var.password}"
    qe.qemu_dir = "${var.qemu_dir}"
    qe.arch = "${local.vagrant_arch}"
    qe.machine = "type=${var.machine},accel=${var.accelerator}"
    qe.cpu = "host"
    qe.net_device = "virtio-net"
    qe.smp = 4
    qe.memory = "8192M"
    qe.ssh_port = "${var.qemu_ssh_port}"
  end
  config.vm.synced_folder ".", "/vagrant", disabled: true
end
EOF
}

source "qemu" "cloudubuntu" {
  vm_name = var.vm_name
  iso_checksum = var.iso_checksum
  disk_image = true
  format = "qcow2"
  iso_url          = local.iso_url
  output_directory = "build/${local.build_timestamp}"
  machine_type = var.machine
  accelerator = var.accelerator
  cpus = 4
  memory = "4096"
  headless = true
  ssh_port = 22
  ssh_username = "${var.username}"
  ssh_password = "${var.password}"
  ssh_timeout = "900s"
  qemu_binary      = local.qemu_binary
  http_content = {
    "/meta-data" = <<EOF
EOF
    "/user-data" = <<EOF
#cloud-config
ssh_pwauth: True
users:
  - name: ${var.username}
    plain_text_passwd: ${var.password}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: sudo
    lock_passwd: false
packages: []
EOF
  }
  qemuargs = concat([
    ["-cpu", "host"],
    ["-smbios", "type=1,serial=ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/"]
  ], local.arm64_args)
  shutdown_command = "sudo -S shutdown -P now"
}

build {
  name = "cloudubuntu"
  sources = [
    "qemu.cloudubuntu"
  ]
  
  post-processors {
    post-processor "vagrant" {
      keep_input_artifact = true
        output = local.vagrant_box
    }
    post-processor "shell-local" {
      inline = ["cat <<EOF >> ${local.build_directory}/Vagrantfile",
"${local.vagrant_file}EOF"
      ]
    }
  }
}
