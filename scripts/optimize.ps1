$ErrorActionPreference = "SilentlyContinue"

Write-Host "Disabling Hibernation..."
powercfg /h off

Write-Host "Disabling System Restore..."
Disable-ComputerRestore -Drive "C:\"

Write-Host "Stopping and Removing OneDrive..."
taskkill /f /im OneDrive.exe
if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
    & "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" /uninstall
}

Write-Host "Removing Appx Packages to prevent Sysprep failures..."
Get-AppxPackage -AllUsers | Where-Object { 
    $_.IsFramework -eq $false -and 
    $_.NonRemovable -eq $false -and 
    $_.Name -notlike "*Microsoft.WindowsStore*" -and 
    $_.Name -notlike "*Microsoft.WindowsCalculator*" 
} | Remove-AppxPackage -AllUsers

Write-Host "Fixing iphlpsvc / tunnel registry hang..."
Stop-Service -Name iphlpsvc -Force
Set-Service -Name iphlpsvc -StartupType Disabled
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\iphlpsvc\Parameters\ProxyMgr" /f

Write-Host "Cleaning up Component Store..."
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

Write-Host "Running Disk Cleanup..."
$cleanmgrRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
Get-ChildItem $cleanmgrRegPath | ForEach-Object {
    New-ItemProperty -Path $_.PSPath -Name StateFlags0001 -Value 2 -PropertyType DWord -Force | Out-Null
}
Start-Process -FilePath cleanmgr.exe -ArgumentList "/sagerun:1" -Wait

Write-Host "Zeroing out free space (this may take a while)..."
$filePath = "C:\zero.tmp"
$volume = Get-Volume -DriveLetter C
$size = ($volume.SizeRemaining) - 100MB
if ($size -gt 0) {
    fsutil file createnew $filePath $size
    Remove-Item $filePath -Force
}

Write-Host "Optimizing Volume..."
Optimize-Volume -DriveLetter C -ReTrim -Verbose

Write-Host "Optimization Complete."
