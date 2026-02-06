$ErrorActionPreference = "Stop"

# Enable WinRM
cmd.exe /c winrm quickconfig -q
cmd.exe /c winrm set winrm/config/service '@{AllowUnencrypted="true"}'
cmd.exe /c winrm set winrm/config/service/auth '@{Basic="true"}'
cmd.exe /c winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'

# Allow WinRM through firewall
netsh advfirewall firewall set rule group="Windows Remote Management" new enable=yes

# Set network profile to private (optional but helpful)
# Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
