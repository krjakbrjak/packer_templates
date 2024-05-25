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
  default = "serverubuntu"
}

variable "iso_url" {
  type = string
  default = "https://releases.ubuntu.com/jammy/ubuntu-22.04.4-live-server-amd64.iso"
}

variable "iso_checksum" {
  type = string
  default = "file:https://releases.ubuntu.com/jammy/SHA256SUMS"
}

variable "qemu_arch" {
  type = string
  default = "x86_64"
}

variable "qemu_binary" {
  type = string
  default = "qemu-system-x86_64"
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
  build_timestamp = timestamp()
  build_directory = "build/${local.build_timestamp}"
  vagrant_box = "${local.build_directory}/${var.vm_name}.box"
  vagrant_file = <<EOF
Vagrant.configure(2) do |config|
  config.vm.box = "${var.vm_name}.box"
  config.vm.provider :qemu do |qe, override|
    override.ssh.username = "packer"
    override.ssh.password = "packer"
    qe.qemu_dir = "${var.qemu_dir}"
    qe.arch = "${var.qemu_arch}"
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

source "qemu" "serverubuntu" {
  vm_name = var.vm_name
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  disk_image = false
  format = "qcow2"
  output_directory = "build/${local.build_timestamp}"
  machine_type = var.machine
  accelerator = var.accelerator
  cpus = 4
  memory = "4096"
  http_directory = "http"
  headless = true
  ssh_port = 22
  ssh_username = "packer"
  ssh_password = "packer"
  ssh_timeout = "900s"
  qemu_binary = var.qemu_binary
  boot_wait = "1s"
  boot_command = [
    "c",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/server' ",
    "<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
  qemuargs = [
    ["-cpu", "host"]
  ]
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
}

build {
  name = "serverubuntu"
  
  sources = [
    "qemu.serverubuntu"
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

  provisioner "shell" {
    inline = [
      "/usr/bin/cloud-init status --wait"
    ]
  }
}
