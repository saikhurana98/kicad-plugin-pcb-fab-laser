# Install the plugin into every detected KiCad user scripting plugins dir (Windows).
# Usage:  powershell -ExecutionPolicy Bypass -File install.ps1
#
# Symlinks need Developer Mode or an elevated shell; falls back to copying.
# A copy is a snapshot: re-run this script after every edit to the plugin.

$ErrorActionPreference = 'Stop'

$srcDir = Join-Path $PSScriptRoot 'pcb_fab_laser'
if (-not (Test-Path $srcDir)) {
    Write-Error "Source dir not found: $srcDir"
}

$kicadRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'KiCad'
if (-not (Test-Path $kicadRoot)) {
    Write-Error "No KiCad user dir at $kicadRoot. Open pcbnew's Tools -> External Plugins to locate your plugin folder, then copy pcb_fab_laser\ into it manually."
}

$found = 0
foreach ($verDir in Get-ChildItem -Path $kicadRoot -Directory) {
    if ($verDir.Name -notmatch '^\d+\.\d+') { continue }

    $destParent = Join-Path $verDir.FullName 'scripting\plugins'
    New-Item -ItemType Directory -Force -Path $destParent | Out-Null
    $dest = Join-Path $destParent 'pcb_fab_laser'

    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }

    try {
        New-Item -ItemType SymbolicLink -Path $dest -Target $srcDir -ErrorAction Stop | Out-Null
        Write-Host "Linked: $dest -> $srcDir"
    } catch {
        Copy-Item -Recurse $srcDir $dest
        Write-Host "Copied (no symlink privilege): $dest"
    }
    $found = 1
}

if ($found -eq 0) {
    Write-Error "No KiCad version dirs found under $kicadRoot"
}

Write-Host ""
Write-Host "In KiCad: Tools -> External Plugins -> Refresh Plugins"
Write-Host "Then: Tools -> External Plugins -> 'PCB Fab Laser SVG Export'"
