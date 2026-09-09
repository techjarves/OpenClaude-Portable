$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$Version = '22.23.2'
$Arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'x64' }
$NodeDir = Join-Path $ProjectRoot "engine/node-win32-$Arch"
$NodeExe = Join-Path $NodeDir 'node.exe'
$NeedsNode = !(Test-Path $NodeExe)
if (!$NeedsNode) { $NeedsNode = ((& $NodeExe --version) -ne "v$Version") }
if ($NeedsNode) {
    $ArchiveName = "node-v$Version-win-$Arch.zip"
    $Base = "https://nodejs.org/dist/v$Version"
    $Engine = Join-Path $ProjectRoot 'engine'
    New-Item -ItemType Directory -Force -Path $Engine | Out-Null
    $Archive = Join-Path $Engine $ArchiveName
    Write-Host 'Downloading portable Node.js from nodejs.org…'
    Invoke-WebRequest "$Base/$ArchiveName" -OutFile $Archive
    $Checksums = (Invoke-WebRequest "$Base/SHASUMS256.txt").Content
    $Expected = (($Checksums -split "`n" | Where-Object { $_.Trim().EndsWith(" $ArchiveName") }) -split '\s+')[0]
    if (!$Expected -or (Get-FileHash $Archive -Algorithm SHA256).Hash.ToLower() -ne $Expected) { throw 'Node.js checksum verification failed' }
    Expand-Archive -Path $Archive -DestinationPath $Engine -Force
    if (Test-Path $NodeDir) { Move-Item $NodeDir "$NodeDir.previous.$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" }
    Move-Item (Join-Path $Engine "node-v$Version-win-$Arch") $NodeDir
    Remove-Item $Archive
}
& $NodeExe (Join-Path $ProjectRoot 'tools/launcher.mjs') @args
exit $LASTEXITCODE
