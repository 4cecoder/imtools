$ErrorActionPreference = 'Stop'

$packageName = 'imtools'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# Remove the executable
$exePath = Join-Path $toolsDir 'imtools.exe'
if (Test-Path $exePath) {
    Remove-Item $exePath -Force
}

Write-Host "imtools has been uninstalled." -ForegroundColor Green
