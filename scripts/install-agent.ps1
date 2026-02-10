[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

Write-Host "Downloading Cloudbase-Init (Stable)..."
$url = "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
$output = "C:\Windows\Temp\CloudbaseInitSetup.msi"

# Use Invoke-WebRequest for better error handling and progress
try {
    Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
} catch {
    Write-Error "Failed to download Cloudbase-Init: $_"
    exit 1
}

# Verify file size (should be > 10MB)
$fileInfo = Get-Item $output
if ($fileInfo.Length -lt 10485760) {
    Write-Error "Downloaded file is too small ($($fileInfo.Length) bytes). Likely corrupted or 404 page."
    exit 1
}

Write-Host "Installing Cloudbase-Init..."
$logFile = "C:\Windows\Temp\cloudbase_install.log"
$process = Start-Process msiexec.exe -ArgumentList "/i $output /qn /norestart /l*v $logFile" -Wait -PassThru

if ($process.ExitCode -ne 0) {
    Write-Error "Cloudbase-Init installation failed with exit code $($process.ExitCode). Check $logFile for details."
    exit $process.ExitCode
}

$installPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init"
if (-not (Test-Path "$installPath\conf\cloudbase-init.conf")) {
    Write-Error "Installation path not found: $installPath\conf\cloudbase-init.conf"
    Get-ChildItem "C:\Program Files" -Recurse -Depth 2
    exit 1
}

Write-Host "Configuring Cloudbase-Init..."
$confFile = "$installPath\conf\cloudbase-init.conf"
$confContent = @"
[DEFAULT]
username=Admin
groups=Administrators
inject_user_password=true
first_logon_behaviour=always
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
log_dir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
log_file=cloudbase-init.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
check_latest_version=true

metadata_services=cloudbaseinit.metadata.services.nocloudservice.NoCloudConfigDriveService,cloudbaseinit.metadata.services.osconfigdrive.windows.WindowsConfigDriveManager

plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,cloudbaseinit.plugins.windows.extendvolumes.ExtendVolumesPlugin,cloudbaseinit.plugins.common.userdata.UserDataPlugin,cloudbaseinit.plugins.windows.createuser.CreateUserPlugin
"@

$confContent | Set-Content $confFile -Encoding UTF8

Write-Host "Cloudbase-Init Installed and Configured."
