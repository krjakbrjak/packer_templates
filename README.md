# Building VMs with Packer (QEMU builder)

[Packer](https://packer.io) is an excellent tool for automating the process of building virtual machine images. The [QEMU builder](https://developer.hashicorp.com/packer/plugins/builders/qemu) is an ideal choice because it's supported across all platforms, including Apple Silicon.

## Prerequisites

The following packages need to be installed on the system:
* [Packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli)
* [Vagrant](https://developer.hashicorp.com/vagrant/docs/installation)
* [QEMU](https://www.qemu.org/download/#source)

## Build

```shell
vagrant plugin install vagrant-qemu # required vagrant plugin
packer init <PACKER_TEMPLATE>
packer build <PACKER_TEMPLATE>
```

## Start VM

```shell
cd build/<TIMESTAMP>
vagrant up
```
