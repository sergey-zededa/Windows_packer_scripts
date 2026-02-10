# Windows 11 Packer Template for QEMU/KVM

This repository contains a Packer template to create a Windows 11 QEMU/KVM image.

## Overview
Automated Windows 11 image creation with:
- **VirtIO Drivers**: Pre-installed for disk, network, and input devices.
- **Cloudbase-Init**: Installed for cloud initialization.
- **Optimization**: Debloating script to remove unnecessary apps and services.
- **Sysprep**: Generalized image ready for deployment.

## Prerequisites

- **Packer**: Installed (v1.7+)
- **QEMU/KVM**: Installed (qemu-system-x86_64)
- **SWTPM**: Software TPM emulator (required for Windows 11)
- **OVMF**: UEFI firmware
- **ISO**: Windows 11 ISO (`iso/Windows11.iso`) and VirtIO drivers (`iso/virtio-win.iso`)

## Usage

1.  **Place ISOs**: Ensure `iso/Windows11.iso` and `iso/virtio-win.iso` exist.
2.  **Run Build**:
    ```bash
    ./build.sh
    ```
    The build script handles:
    - Starting `swtpm` emulator.
    - Running Packer.
    - Monitoring for Sysprep completion.
    - Compressing the output to `windows11-compressed.qcow2`.

## Configuration Details

- **`windows11-qemu.pkr.hcl`**: Main Packer configuration.
- **`scripts/sysprep-shutdown.ps1`**: Custom shutdown script that handles `iphlpsvc` hang issues and runs Sysprep.
- **`answer_files/11/autounattend.xml`**: Unattended installation settings.

## Troubleshooting

- **Sysprep Hangs**: The `iphlpsvc` service is known to cause hangs during the generalization phase. The `scripts/sysprep-shutdown.ps1` script explicitly stops this service and cleans up its registry keys to prevent this.
- **VNC**: You can connect to VNC on port `5900` (or as assigned) to monitor the installation process. The Sysprep window is visible (not hidden) to aid in debugging.

## OOBE Bypass
To bypass Windows 11 OOBE (Microsoft Account requirement), a custom `unattend.xml` is used during the final Sysprep generalization.
- **`scripts/unattend.xml`**: Configures OOBE to be skipped and sets `BypassNRO` registry key.
- **`scripts/sysprep-shutdown.ps1`**: Applies this unattend file via `Sysprep /unattend:...`.
