# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

# Project Overview

This repository contains HashiCorp Packer templates for building Windows 11 images.
It supports two build targets:
1.  **QEMU/KVM**: For local development/testing (`windows11-qemu.pkr.hcl`).
2.  **Proxmox**: For creating templates on a Proxmox VE cluster (`windows11.pkr.hcl`).

The primary goal is to produce a "Cloud-Ready" image compatible with EVE-OS, replicating the manual creation steps.

# Architecture

*   **Packer Configurations (`*.pkr.hcl`)**: define the build steps, provisioners, and builders.
    *   `windows11-qemu.pkr.hcl`: Uses the `qemu` builder.
    *   `windows11.pkr.hcl`: Uses the `proxmox-iso` builder.
*   **`answer_files/`**: Contains the `autounattend.xml` file used for automated Windows installation.
    *   Configures a default administrator user: `packer` / `packer`.
    *   Enables WinRM for Packer provisioning.
*   **`scripts/`**: PowerShell scripts run during the provisioning phase.
    *   `enable-winrm.ps1`: Configures WinRM.
    *   `install-agent.ps1`: Installs required agents.
    *   `win-updates.ps1`: Runs Windows updates.
*   **`iso/`**: Expected location for source ISOs when building locally.
    *   `Windows11.iso`: The Windows 11 installation media.
    *   `virtio-win.iso`: VirtIO drivers for Windows.

# Reference: Manual Process (EVE-OS Master Guide)

The goal of this Packer automation is to replicate the manual process described in "Windows 11 Cloud-Ready Image Creation Master Guide for EVE-OS".
The manual process typically involves:
1.  **VM Creation**: Creating a VM on Proxmox with VirtIO network and disk drivers.
2.  **OS Installation**: Installing Windows 11.
3.  **Drivers**: Installing `virtio-win` drivers (NetKVM, vioscsi, qxl, etc.) to ensure performance and connectivity.
4.  **Updates**: Fully patching Windows via Windows Update.
5.  **Cloud-Ready Agent**: Installing **Cloudbase-Init** to handle host initialization (hostname, user creation, userdata) on EVE-OS.
6.  **Cleanup**: Running Sysprep to generalize the image for template usage.

## Implementation Status
*   **VirtIO**: Handled by `virtio-win.iso` and driver installation scripts.
*   **Cloudbase-Init**: Installed via `scripts/install-agent.ps1` (downloads from GitHub).
*   **Updates**: `scripts/win-updates.ps1` (currently a placeholder, may need expansion to match the guide's requirement for full updates).
*   **Sysprep**: Typically handled by Cloudbase-Init or the final shutdown command.

# Development

## Prerequisites
*   **Packer**: Must be installed.
*   **Virtualization**: QEMU/KVM for local builds.
*   **ISOs**: Ensure `iso/Windows11.iso` and `iso/virtio-win.iso` exist or update the variables to point to their locations.

## Common Commands

### Initialization
Before running builds, initialize the Packer configuration to install required plugins.

```bash
packer init windows11-qemu.pkr.hcl
# OR
packer init windows11.pkr.hcl
```

### Validation
Check the syntax and configuration validity.

```bash
packer validate windows11-qemu.pkr.hcl
```

### Building for QEMU (Local)
Run the build locally using QEMU.

```bash
packer build windows11-qemu.pkr.hcl
```
*Note: This defaults to looking for ISOs in the `iso/` directory.*

### Building for Proxmox
Run the build targeting a Proxmox server. You MUST provide the `proxmox_password` variable, and likely override other defaults (URL, user, node).

```bash
packer build \
  -var "proxmox_password=$PROXMOX_PASSWORD" \
  -var "proxmox_url=https://YOUR_PVE_IP:8006/api2/json" \
  windows11.pkr.hcl
```

## Key Variables
*   **`proxmox_password`**: Required for Proxmox builds (sensitive).
*   **`iso_url` / `iso_file`**: Path to the Windows 11 ISO.
*   **`virtio_iso_url` / `virtio_iso_file`**: Path to the VirtIO drivers ISO.
