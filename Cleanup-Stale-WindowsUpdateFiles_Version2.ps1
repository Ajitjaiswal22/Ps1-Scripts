<#
.SYNOPSIS
    Cleans up stale files related to Windows Update Group Policy on hybrid Intune-managed devices.

.DESCRIPTION
    Checks and removes:
      - Stale Group Policy cache files linked to Windows Update
      - Registry entries that might block MDM/Intune update management
      - Windows Update cache folders that may conflict after policy changes

.NOTES
    Run as an administrator. Always back up critical data before performing cleanups on production systems.
#>

Write-Host "Starting manual cleanup of stale Windows Update policy and cache files..." -ForegroundColor Cyan

# 1. Clean stale Group Policy cache files (WinUpdate.admx/adml)
$GPPolicyPaths = @(
    "$env:SystemRoot\System32\GroupPolicy\Machine",
    "$env:SystemRoot\System32\GroupPolicy\User",
    "$env:SystemRoot\SysWOW64\GroupPolicy\Machine",
    "$env:SystemRoot\SysWOW64\GroupPolicy\User"
)

foreach ($path in $GPPolicyPaths) {
    if (Test-Path "$path") {
        Get-ChildItem -Path "$path" -Filter "*Win*.pol" -Recurse | Remove-Item -Force
        Write-Host "Cleaned up stale .pol files in: $path" -ForegroundColor Green
    }
}

# 2. Remove Windows Update registry policies set by previous GPOs
$WUPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
)
foreach ($regKey in $WUPaths) {
    if (Test-Path $regKey) {
        Remove-Item $regKey -Recurse -Force
        Write-Host "Removed registry key: $regKey" -ForegroundColor Green
    }
}

# 3. Clear Windows Update cache
$WUCachePaths = @(
    "$env:SystemRoot\SoftwareDistribution\Download",
    "$env:SystemRoot\SoftwareDistribution\DataStore"
)
foreach ($cachePath in $WUCachePaths) {
    if (Test-Path "$cachePath") {
        Remove-Item "$cachePath" -Recurse -Force
        Write-Host "Cleared Windows Update cache: $cachePath" -ForegroundColor Green
    }
}

# 4. Optional: Refresh Group Policy and MDM sync
gpupdate /force
Write-Host "Group Policy has been updated forcefully." -ForegroundColor Yellow

Write-Host "Manual cleanup completed. Please reboot the device for changes to take effect." -ForegroundColor Cyan