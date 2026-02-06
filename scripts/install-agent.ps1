[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

Write-Host "Downloading Cloudbase-Init..."
$url = "https://github.com/cloudbase/cloudbase-init/releases/download/1.1.4/CloudbaseInitSetup_1.1.4_x64.msi"
$output = "C:\Windows\Temp\CloudbaseInitSetup.msi"
curl.exe -L -o $output $url

Write-Host "Installing Cloudbase-Init..."
Start-Process msiexec.exe -ArgumentList "/i $output /qn /norestart" -Wait

Write-Host "Cloudbase-Init Installed."
