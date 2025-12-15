$ErrorActionPreference = 'Stop'

$packageName = 'imtools'
$url64 = 'https://github.com/4cecoder/imtools/releases/download/v1.0.0/imtools-1.0.0-windows-x86_64.zip'
$checksum64 = 'REPLACE_WITH_ACTUAL_SHA256'
$checksumType64 = 'sha256'

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
    packageName    = $packageName
    unzipLocation  = $toolsDir
    url64bit       = $url64
    checksum64     = $checksum64
    checksumType64 = $checksumType64
}

Install-ChocolateyZipPackage @packageArgs

Write-Host ""
Write-Host "imtools has been installed!" -ForegroundColor Green
Write-Host ""
Write-Host "Optional dependencies for full functionality:"
Write-Host "  choco install ffmpeg   # for convert-to-png and download commands"
Write-Host ""
Write-Host "For AI-powered sorting, install Ollama from https://ollama.ai"
Write-Host ""
