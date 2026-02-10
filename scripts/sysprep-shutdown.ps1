Write-Host "sysprep-shutdown.ps1: Started."

# Fix iphlpsvc hang - Aggressive Cleanup
Write-Host "sysprep-shutdown.ps1: mitigating iphlpsvc hang..."
Stop-Service -Name iphlpsvc -Force -ErrorAction SilentlyContinue
Set-Service -Name iphlpsvc -StartupType Disabled -ErrorAction SilentlyContinue
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\iphlpsvc\Parameters\ProxyMgr" /f

# Wait for potential startup processes to settle
Write-Host "sysprep-shutdown.ps1: Waiting 60s for system to settle..."
Start-Sleep -Seconds 60

# Wait for TrustedInstaller/TiWorker (Windows Modules Installer)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalMinutes -lt 15) {
    $installers = Get-Process -Name "TrustedInstaller", "TiWorker", "msiexec" -ErrorAction SilentlyContinue
    if (-not $installers) {
        Write-Host "sysprep-shutdown.ps1: No active installers found. Proceeding."
        break
    }
    $names = $installers | Select-Object -ExpandProperty Name -Unique
    Write-Host "sysprep-shutdown.ps1: Waiting for installers to finish: $($names -join ', ')..."
    Start-Sleep -Seconds 10
}

if ($sw.Elapsed.TotalMinutes -ge 15) {
    Write-Warning "sysprep-shutdown.ps1: Timed out waiting for installers. Proceeding anyway..."
}

# Run Sysprep
Write-Host "sysprep-shutdown.ps1: Launching Sysprep..."
$sysprepPath = Join-Path $env:SystemRoot "System32\Sysprep\Sysprep.exe"
$sysprepArgs = "/oobe /generalize /quit "
$p = Start-Process -FilePath $sysprepPath -ArgumentList $sysprepArgs -PassThru -NoNewWindow
Wait-Process -Id $p.Id

Write-Host "sysprep-shutdown.ps1: Sysprep finished. waiting 10s..."
Start-Sleep -Seconds 10

Write-Host "sysprep-shutdown.ps1: Initiating Shutdown..."
& "$env:SystemRoot\System32\shutdown.exe" /s /t 0 /f
