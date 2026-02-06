packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
    windows-update = {
      version = ">= 0.14.3"
      source  = "github.com/rgl/windows-update"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "iso/Windows11.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

variable "virtio_iso_url" {
  type    = string
  default = "iso/virtio-win.iso"
}

source "qemu" "windows11" {
  iso_url           = var.iso_url
  iso_checksum      = var.iso_checksum
  output_directory  = "output-windows11"
  shutdown_command  = "powershell -executionpolicy bypass -c \"& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet\""
  shutdown_timeout  = "1h"
  disk_size         = "65536"
  format            = "qcow2"
  accelerator       = "kvm"
  http_directory    = "."
  ssh_username      = "packer"
  ssh_password      = "packer"
  ssh_timeout       = "4h"
  
  # WinRM
  communicator      = "winrm"
  winrm_username    = "packer"
  winrm_password    = "packer"
  winrm_timeout     = "4h"
  winrm_use_ssl     = false
  winrm_insecure    = true

  # Hardware config
  cpus              = 4
  machine_type      = "q35"
  memory            = 8192
  
  # UEFI (OVMF)
  efi_boot          = true
  headless          = true
  vnc_bind_address  = "0.0.0.0"
  efi_firmware_code = "/usr/share/OVMF/OVMF_CODE_4M.fd"
  efi_firmware_vars = "/usr/share/OVMF/OVMF_VARS_4M.fd"
  
  # Network
  net_device        = "virtio-net"
  disk_interface    = "virtio"
  boot_wait = "2s"
  boot_command = ["<spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar>"]

  floppy_files = [
    "answer_files/11/autounattend.xml",
    "scripts/enable-winrm.ps1"
  ]

  vm_name = "windows11"

  qemuargs = [
    ["-cpu", "host"],
    ["-chardev", "socket,id=chrtpm,path=/tmp/swtpm-sock/swtpm-sock"],
    ["-tpmdev", "emulator,id=tpm0,chardev=chrtpm"],
    ["-device", "tpm-tis,tpmdev=tpm0"],
    
    # Network with Port Forwarding
    # RDP: 0.0.0.0:3389 -> 3389
    # WinRM: 0.0.0.0:{{ .SSHHostPort }} -> 5985 (This tells QEMU to use the port Packer selected)
    ["-netdev", "user,id=user.0,hostfwd=tcp:0.0.0.0:3389-:3389,hostfwd=tcp:0.0.0.0:{{ .SSHHostPort }}-:5985"],
    ["-device", "virtio-net,netdev=user.0"],

    # UEFI Firmware
    ["-drive", "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd"],
    ["-drive", "if=pflash,format=raw,file=OVMF_VARS.fd"],
    
    # Main Disk
    ["-drive", "file=output-windows11/windows11,if=virtio,cache=writeback,discard=ignore,format=qcow2,index=1"],
    
    # Main ISO (Windows) - Index 2
    ["-drive", "file=${var.iso_url},media=cdrom,index=2"],

    # VirtIO Drivers - Index 3
    ["-drive", "file=${var.virtio_iso_url},if=none,id=drivers,media=cdrom,readonly=on,index=3"],
    ["-device", "qemu-xhci,id=xhci"],
    ["-device", "usb-storage,drive=drivers,bus=xhci.0"]
  ]
}

build {
  sources = ["source.qemu.windows11"]

  provisioner "powershell" {
    inline = [
      "Write-Host 'VirtIO Drivers check skipped (already installed).'"
    ]
  }

  provisioner "powershell" {
    script = "./scripts/install-agent.ps1"
  }
  
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    script = "./scripts/optimize.ps1"
  }
}
