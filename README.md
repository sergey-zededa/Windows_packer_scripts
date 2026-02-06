# Windows 11 QEMU Packer Template

This project automates the creation of a Windows 11 QEMU/KVM image using Packer. It handles the full installation process, including UEFI boot, vTPM emulation, VirtIO driver installation, and basic system configuration via `autounattend.xml`.

## Prerequisites

**Host System:** Ubuntu Linux (24.04 recommended)

### 1. Install QEMU and KVM
Ensure your system supports virtualization (`kvm-ok`) and install the necessary virtualization packages:
```bash
sudo apt-get update
sudo apt-get install -y qemu-system-x86 qemu-utils ovmf
```

### 2. Install swtpm (Software TPM)
Windows 11 requires a TPM 2.0. We use `swtpm` to emulate this without needing to pass through a physical TPM.
```bash
sudo apt-get install -y swtpm swtpm-tools
```

### 3. Install Packer
Follow the official HashiCorp instructions to install Packer:
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install packer
```

### 4. Required Files
Ensure the following files are present in the project directory:
*   `iso/Windows11.iso`: The Windows 11 installation media.
*   `iso/virtio-win.iso`: VirtIO drivers ISO (download from Fedora/RedHat).
*   `drivers/`: Extracted content of the VirtIO ISO (specifically `amd64/w11` and `NetKVM`).

## Project Structure
*   `windows11-qemu.pkr.hcl`: The main Packer template.
*   `build.sh`: Wrapper script to manage the swtpm lifecycle and run Packer.
*   `answer_files/11/autounattend.xml`: Windows Setup answer file for unattended installation.
*   `scripts/`: Contains provisioner scripts (`install-agent.ps1`, `enable-winrm.ps1`).

## Usage
Do not run `packer build` directly. Use the provided wrapper script which handles the vTPM socket creation and cleanup.

```bash
./build.sh
```

## Monitoring the Build (VNC)
Packer will start a VNC server for the VM. The wrapper script suppresses debug noise so you can see the connection details.
*   Look for the line: `qemu: VNC available on 0.0.0.0:<PORT>` (usually 59xx).
*   Connect using a VNC client (e.g., Remmina, RealVNC):
    *   **Host:** `localhost` (or the IP of your build server)
    *   **Port:** `<PORT>`

## Debugging with RDP
Port forwarding is configured for RDP to allow easier troubleshooting if the build pauses or completes installation but hangs.
*   **Host:** `127.0.0.1`
*   **Port:** `3389`
*   **User:** `packer`
*   **Password:** `packer`

```bash
xfreerdp /v:127.0.0.1:3389 /u:packer /p:packer /cert:ignore
```

## Configuration Details

### Partitioning (UEFI)
The `autounattend.xml` is configured to wipe Disk 0 and perform a clean UEFI partitioning scheme:
*   **EFI System Partition (ESP):** 100MB, FAT32
*   **MSR Partition:** 128MB
*   **Windows (Primary):** Remainder, NTFS

### Driver Injection
VirtIO drivers for Storage (`viostor`) and Network (`NetKVM`) are injected during the `windowsPE` pass. These are loaded from the Answer File CD (Drive E: or similar) where Packer bundles the `./drivers/*` directory.

### WinRM Configuration
To allow Packer to connect, WinRM is configured via `FirstLogonCommands`:
*   **Network Profile:** Forced to Private via Registry hacks and PowerShell commands to bypass "Public" network restrictions.
*   **Listener:** A cmd loop searches all drives (D, E, F) for `enable-winrm.ps1` and executes it with `ExecutionPolicy Bypass`.
*   **Auth:** Basic Authentication and Unencrypted traffic are enabled.

## Current Status (Known Issues)
The build process successfully installs Windows 11, boots to the desktop, and logs in. However, Packer currently times out waiting for WinRM to become available.

### Troubleshooting Steps Taken:
*   Fixed partition layout to resolve "Windows cannot be installed to this disk" errors.
*   Added `NetKVM` drivers to ensure network connectivity.
*   Switched to `curl.exe` for file downloads to avoid TLS issues.
*   Added robust cmd loops to locate scripts.

### Next Steps:
If the build hangs at "Waiting for WinRM", connect via RDP or VNC and verify:
1.  Is the Network Profile "Private"?
2.  Is the WinRM service running?
3.  Is the firewall rule enabled for port 5985?
