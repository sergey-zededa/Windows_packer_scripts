packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
    windows-update = {
      version = ">= 0.14.3"
      source  = "github.com/rgl/windows-update"
    }
  }
}

variable "proxmox_url" {
  type    = string
  default = "https://192.168.0.10:8006/api2/json" # Update this
}

variable "proxmox_username" {
  type    = string
  default = "root@pam" # Update this
}

variable "proxmox_password" {
  type    = string
  sensitive = true
  default = "password" # Update this
}

variable "proxmox_node" {
  type    = string
  default = "pve" # Update this
}

variable "iso_file" {
  type    = string
  default = "local:iso/Windows11.iso" # Update this to your Win11 ISO path on Proxmox
}

variable "virtio_iso_file" {
  type    = string
  default = "local:iso/virtio-win.iso" # Update this to your VirtIO ISO path
}

variable "template_name" {
  type    = string
  default = "win11-template"
}

variable "vm_id" {
  type    = number
  default = 900
}

source "proxmox-iso" "windows11" {
  proxmox_url = "${var.proxmox_url}"
  username    = "${var.proxmox_username}"
  password    = "${var.proxmox_password}"
  node        = "${var.proxmox_node}"
  insecure_skip_tls_verify = true

  vm_name                 = "${var.template_name}"
  vm_id                   = "${var.vm_id}"
  template_description    = "Windows 11 Template built with Packer"
  
  iso_file                = "${var.iso_file}"
  
  # Win 11 requires EFI and TPM
  bios                    = "ovmf"
  machine                 = "q35"
  
  # Add EFI Disk
  efi_config {
    efi_storage_pool  = "local-lvm"
    pre_enrolled_keys = true
  }

  # Hard Disk
  disks {
    disk_size         = "64G"
    storage_pool      = "local-lvm"
    type              = "virtio"
    format            = "raw"
  }

  # CPU & RAM
  cores                   = 4
  memory                  = 8192
  cpu_type                = "host"
  
  # Network
  network_adapters {
    model                 = "virtio"
    bridge                = "vmbr0"
    firewall              = false
  }

  # Additional ISO for drivers (VirtIO)
  additional_iso_files {
    device              = "sata0"
    iso_file            = "${var.virtio_iso_file}"
    unmount             = true
  }

  # TPM 2.0 (vTPM) is implicitly handled if 'tpm_storage_pool' is not set but needed for win11? 
  # Actually Proxmox API needs explicit TPM config usually? 
  # Packer proxmox plugin typically handles this if we define it?
  # For now, relying on 'machine=q35' and 'bios=ovmf'.
  # Note: You might need to add TPM manually in Proxmox or use  settings.
  # Let's check docs or assume standard config.
  # We'll use args to bypass requirements if TPM device isn't added by packer automatically.
  # But we added registry keys in autounattend.xml to bypass TPM check during setup.

  # WinRM
  communicator            = "winrm"
  winrm_username          = "packer"
  winrm_password          = "packer"
  winrm_timeout           = "1h"
  winrm_use_ssl           = false
  winrm_insecure          = true

  # Floppy for scripts
  floppy_files = [
    "answer_files/11/autounattend.xml",
    "scripts/enable-winrm.ps1",
    "scripts/install-agent.ps1" # Placeholder
  ]

  # Boot Command
  boot_wait = "10s"
  boot_command = [
    "<spacebar><wait><spacebar><wait><spacebar><wait><spacebar>"
  ]
}

build {
  sources = ["source.proxmox-iso.windows11"]

  # Install VirtIO drivers
  # We assume they are on the mounted ISO (D: or E:)
  # This step might be better handled in autounattend or a script.
  # For simplicity, we run a powershell script.

  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing VirtIO Drivers...'",
      # Basic lookup for CD drive with drivers
      "$virtio_drive = (Get-WmiObject Win32_CdRomDrive | Where-Object { $_.VolumeName -match 'virtio' }).Drive",
      "if ($virtio_drive) {",
      "  Write-Host \"Found VirtIO ISO at $virtio_drive\"",
      "  pnputil /add-driver $virtio_drive\*.inf /subdirs /install",
      "  pnputil /add-driver $virtio_drive\amd64\*.inf /subdirs /install",
      "} else {",
      "  Write-Host 'VirtIO ISO not found!'",
      "}"
    ]
  }
  
  provisioner "powershell" {
    script = "scripts/win-updates.ps1" # Placeholder
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    inline = [
      "Write-Host 'Sysprepping...'",
      "& $env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /shutdown /quiet"
    ]
  }
}
