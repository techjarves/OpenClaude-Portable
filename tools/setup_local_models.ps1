$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = (Resolve-Path "$ScriptDir\..").Path
$DataDir = "$RootDir\data"
$EnvFile = "$DataDir\ai_settings.env"
$ModelsDir = "$DataDir\models"
$OllamaDir = "$DataDir\ollama"

$ModelCatalog = @(
    # Category 1: Gemma 4 Family (Optimized GGUFs)
    @{ Num=1; Category="Gemma 4 Family (Optimized GGUFs)"; Name="Gemma 4 E2B (Q4_K_M)"; Tag="https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf"; Size="3.1"; Input="Text"; Label="STANDARD"; Badge="BEST BALANCE" },
    @{ Num=2; Category="Gemma 4 Family (Optimized GGUFs)"; Name="Gemma 4 E2B (Q6_K)"; Tag="https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q6_K.gguf"; Size="4.5"; Input="Text"; Label="STANDARD"; Badge="STRONG CPU/GPU" },
    @{ Num=3; Category="Gemma 4 Family (Optimized GGUFs)"; Name="Gemma 4 E4B (Q4_K_M)"; Tag="https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-Q4_K_M.gguf"; Size="5.0"; Input="Text"; Label="STANDARD"; Badge="MOST USERS" },
    
    # Category 2: Qwen 3.5 & Ministral 3
    @{ Num=4; Category="Qwen 3.5 & Ministral 3 (Daily Drivers)"; Name="Qwen 3.5 (9B)"; Tag="qwen3.5:9b"; Size="6.6"; Input="Text, Image"; Label="STANDARD"; Badge="RECOMMENDED" },
    @{ Num=5; Category="Qwen 3.5 & Ministral 3 (Daily Drivers)"; Name="Ministral 3 (8B)"; Tag="ministral-3:8b"; Size="6.0"; Input="Text, Image"; Label="STANDARD"; Badge="DAILY" }
)

function Get-USBFreeSpaceGB {
    try {
        $driveLetter = (Get-Item $ScriptDir).PSDrive.Name
        $drive = Get-PSDrive $driveLetter -ErrorAction SilentlyContinue
        if ($drive) { return [math]::Round($drive.Free / 1GB, 1) }
    } catch {}
    return -1
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   PORTABLE AI USB - Local Model Setup (Official)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$freeGB = Get-USBFreeSpaceGB
if ($freeGB -gt 0) { Write-Host "  USB Free Space: $freeGB GB" -ForegroundColor DarkGray; Write-Host "" }

Write-Host "[1/4] Choose your AI model(s):" -ForegroundColor Yellow

$currentCategory = ""
foreach ($m in $ModelCatalog) {
    if ($m.Category -ne $currentCategory) {
        $currentCategory = $m.Category
        Write-Host "`n  --- $currentCategory ---" -ForegroundColor Cyan
    }
    
    if ($m.Label -eq "UNCENSORED") { $labelColor = "Red"; $labelStr = " [UNCENSORED]" }
    elseif ($m.Label -in @("UTILITY", "VISION", "POWERFUL")) { $labelColor = "DarkYellow"; $labelStr = " [$($m.Label)]" }
    elseif ($m.Label -eq "CLOUD") { $labelColor = "Magenta"; $labelStr = " [CLOUD-API]" }
    else { $labelColor = "DarkCyan"; $labelStr = " [STANDARD]" }
    
    $badgeStr = if ($m.Badge) { " - $($m.Badge)" } else { "" }
    
    $padNum = $m.Num.ToString().PadLeft(2)
    Write-Host "  [$padNum]" -ForegroundColor Yellow -NoNewline
    Write-Host " $($m.Name.PadRight(24))" -ForegroundColor White -NoNewline
    Write-Host ("[" + $m.Input + "]").PadRight(16) -ForegroundColor DarkCyan -NoNewline
    
    $sizeStr = if ($m.Size -eq "-") { " (-)".PadRight(12) } else { " (~$($m.Size) GB)".PadRight(12) }
    Write-Host $sizeStr -ForegroundColor DarkGray -NoNewline
    
    Write-Host $labelStr -ForegroundColor $labelColor -NoNewline
    Write-Host $badgeStr -ForegroundColor Magenta
}

# --- Detect Already Downloaded Models (not in preset list) ---
$ManifestDir = "$OllamaDir\data\manifests\registry.ollama.ai\library"
$DlStartNum = 6
$DlCount = 0

if (Test-Path $ManifestDir) {
    $PresetSkipRegex = 'gemma-4-e2b-it-q4_k_m-local|gemma-4-e2b-it-q6_k-local|gemma-4-e4b-it-q4_k_m-local|qwen3.5|ministral-3'
    $ModelDirs = Get-ChildItem -Path $ManifestDir -Directory -ErrorAction SilentlyContinue
    
    foreach ($dir in $ModelDirs) {
        $modelBase = $dir.Name
        $TagFiles = Get-ChildItem -Path $dir.FullName -File -ErrorAction SilentlyContinue
        foreach ($file in $TagFiles) {
            $tagName = $file.Name
            $fullTag = if ($tagName -eq "latest") { $modelBase } else { "${modelBase}:${tagName}" }
            
            if ($fullTag -match $PresetSkipRegex) { continue }
            
            # Read JSON size simply (using regex to avoid full parsing overhead if invalid JSON)
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match '"size"\s*:\s*(\d+)') {
                $sizeBytes = [long]$matches[1]
                if ($sizeBytes -lt 100000000) { continue } # Skip < 100MB
                
                $sizeGB = [math]::Round($sizeBytes / 1GB, 1)
                $Num = $DlStartNum + $DlCount
                
                # Append to ModelCatalog so existing selection logic works automatically
                $ModelCatalog += @{ Num=$Num; Category="Already Downloaded"; Name=$fullTag; Tag=$fullTag; Size=$sizeGB.ToString(); Input="Text"; Label="DOWNLOADED"; Badge="" }
                $DlCount++
            }
        }
    }
}

if ($DlCount -gt 0) {
    Write-Host "`n  --- " -ForegroundColor Cyan -NoNewline
    Write-Host "Already Downloaded" -ForegroundColor Green -NoNewline
    Write-Host " ---" -ForegroundColor Cyan
    
    $dlModels = $ModelCatalog | Where-Object { $_.Category -eq "Already Downloaded" }
    foreach ($m in $dlModels) {
        $padNum = $m.Num.ToString().PadLeft(2)
        Write-Host "  [$padNum]" -ForegroundColor Yellow -NoNewline
        Write-Host " $($m.Name.PadRight(24))" -ForegroundColor White -NoNewline
        Write-Host ("[" + $m.Input + "]").PadRight(16) -ForegroundColor DarkCyan -NoNewline
        Write-Host " (~$($m.Size) GB)".PadRight(12) -ForegroundColor DarkGray -NoNewline
        Write-Host " [DOWNLOADED]" -ForegroundColor Green
    }
}

Write-Host "`n  [C] CUSTOM - Enter an Official Ollama Tag" -ForegroundColor Green
Write-Host "      Browse ALL models here: " -ForegroundColor Gray -NoNewline
Write-Host "https://ollama.com/library" -ForegroundColor Blue
Write-Host "`n  ------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Enter number(s) separated by commas  (e.g. 1,4)" -ForegroundColor Gray
Write-Host "  Type 'all' for every preset model, 'c' for custom`n" -ForegroundColor Gray

$UserChoice = Read-Host "  Your choice"
if ([string]::IsNullOrWhiteSpace($UserChoice)) {
    Write-Host "`n  No input! Defaulting to [3] Gemma 4 E4B..." -ForegroundColor Yellow
    $UserChoice = "3"
}

$SelectedModels = @()
$HasCustom = $false

if ($UserChoice.Trim().ToLower() -eq "all") { $SelectedModels = @($ModelCatalog) }
else {
    foreach ($t in ($UserChoice -split "," | ForEach-Object { $_.Trim().ToLower() })) {
        if ($t -eq "c" -or $t -eq "custom") { $HasCustom = $true }
        elseif ($t -match '^\d+$') {
            $num = [int]$t
            $found = $ModelCatalog | Where-Object { $_.Num -eq $num }
            if ($found -and -Not ($SelectedModels | Where-Object { $_.Num -eq $num })) { $SelectedModels += $found }
        }
    }
}

if ($HasCustom) {
    Write-Host "`n  ---- Custom Model Setup ----" -ForegroundColor Green
    $customTag = Read-Host "  Ollama Tag (e.g. mistral-nemo, phi3)"
    if ($customTag) {
        $customName = (CultureInfo.CurrentCulture.TextInfo.ToTitleCase($customTag.ToLower()))
        $SelectedModels += @{ Num=99; Name="Custom: $customName"; Tag=$customTag.Trim(); Size="?"; Label="CUSTOM" }
        Write-Host "  Custom model added!" -ForegroundColor Green
    }
}

if ($SelectedModels.Count -eq 0) { Write-Host "`n  ERROR: No models selected!" -ForegroundColor Red; exit 1 }

$totalSizeGB = 0
foreach ($m in $SelectedModels) {
    if ($m.Size -match '\d') { $totalSizeGB += [double]$m.Size }
}

if ($totalSizeGB -ge ($freeGB - 1) -and $freeGB -gt 0 -or $UserChoice.Trim().ToLower() -eq "all") {
    Write-Host "`n  WARNING: These models total ~$([math]::Ceiling($totalSizeGB)) GB. USB drive has $freeGB GB free!" -ForegroundColor Red
    $confirm = Read-Host "  Continue? (yes/no)"
    if ($confirm.Trim().ToLower() -ne "yes" -and $confirm.Trim().ToLower() -ne "y") { exit }
}

# Directories
New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null
New-Item -ItemType Directory -Force -Path "$OllamaDir\data" | Out-Null
Write-Host "`n[2/4] Created storage folders." -ForegroundColor Green

# Ollama Engine Setup
Write-Host "`n[3/4] Setting up Portable Ollama Engine..." -ForegroundColor Yellow
$OllamaURL = "https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.zip"
$OllamaDest = "$OllamaDir\ollama.zip"
$OllamaExe = "$OllamaDir\ollama.exe"

if (Test-Path $OllamaExe) { 
    Write-Host "      Engine already installed!" -ForegroundColor Green 
} else {
    Write-Host "      Downloading Ollama Engine (~100MB)..." -ForegroundColor Yellow
    curl.exe -L --ssl-no-revoke $OllamaURL -o $OllamaDest
    if (Test-Path $OllamaDest) {
        Write-Host "      Extracting to USB..." -ForegroundColor Yellow
        Expand-Archive -Path $OllamaDest -DestinationPath $OllamaDir -Force
        Remove-Item $OllamaDest -Force -ErrorAction SilentlyContinue
        Write-Host "      Engine Installed successfully!" -ForegroundColor Green
    } else { 
        Write-Host "      ERROR: Failed to download engine!" -ForegroundColor Red
        exit 1 
    }
}

# Downloading Models via Ollama
Write-Host "`n[4/4] Pulling Models (This guarantees perfectly configured Tool Support)..." -ForegroundColor Yellow

$downloadErrors = @()

$env:OLLAMA_MODELS = "$OllamaDir\data"
Write-Host "`n      Starting background Ollama server on USB..." -ForegroundColor DarkGray
$ServerProcess = Start-Process -FilePath $OllamaExe -ArgumentList "serve" -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 5

$idx = 1
foreach ($m in $SelectedModels) {
    if ($m.Tag -match "^http.*" -and $m.Tag -match "\.gguf") {
        $tagUrlNoQuery = $m.Tag.Split('?')[0]
        $fileName = $tagUrlNoQuery.Split('/')[-1]
        if (-not $fileName.EndsWith(".gguf")) { $fileName += ".gguf" }
        $dest = "$ModelsDir\$fileName"
        
        $baseName = $fileName -ireplace '\.gguf$', ''
        $modelNameLocal = "$baseName-local".ToLower() -replace '[^a-z0-9_-]', '-'

        # --- Always verify real file size against server ---
        Write-Host "`n  ($idx/$($SelectedModels.Count)) Checking $($m.Name)..." -ForegroundColor Yellow
        $idx++
        
        $expectedSize = 0
        $existingSize = 0
        try {
            $headResponse = Invoke-WebRequest -Uri $m.Tag -Method Head -UseBasicParsing -ErrorAction Stop
            $expectedSize = [long]$headResponse.Headers['Content-Length']
        } catch {}
        if (Test-Path $dest) { $existingSize = (Get-Item $dest).Length }
        
        $fileComplete = ($expectedSize -gt 0 -and $existingSize -ge $expectedSize)
        
        # Only skip if file is FULLY downloaded AND ollama has it imported
        $showResult = & $OllamaExe show $modelNameLocal 2>&1
        if ($fileComplete -and $LASTEXITCODE -eq 0) {
            $existMegabytes = [math]::Round($existingSize / 1MB)
            Write-Host ("  $([char]0x2705) {0} fully downloaded ({1} MB) & imported - skipping!" -f $m.Name, $existMegabytes) -ForegroundColor Green
            $m.Tag = $modelNameLocal
            continue
        }

        Write-Host "      Do not close this window! Download may take a while." -ForegroundColor Magenta
        
        try {
            # --- Download or resume ---
            if ((Test-Path $dest) -and -not $fileComplete) {
                $existMegabytes = [math]::Round($existingSize / 1MB)
                $expectMegabytes = [math]::Round($expectedSize / 1MB)
                Write-Host ("      {0} is incomplete ({1} MB / {2} MB). Resuming..." -f $fileName, $existMegabytes, $expectMegabytes) -ForegroundColor Yellow
                curl.exe -L -C - $($m.Tag) -o $dest
            } elseif (-not $fileComplete) {
                Write-Host "      Downloading $fileName (speed + ETA shown below)..." -ForegroundColor Cyan
                curl.exe -L -C - $($m.Tag) -o $dest
            }
            
            $modelFileContent = "FROM ./$fileName`nPARAMETER temperature 0.7`nPARAMETER top_p 0.9"
            $modelFilePath = "$ModelsDir\Modelfile-$modelNameLocal"
            Set-Content -Path $modelFilePath -Value $modelFileContent -Encoding Ascii
            
            Write-Host "      Importing into Ollama as '$modelNameLocal'..." -ForegroundColor Cyan
            Push-Location $ModelsDir
            $createArgs = "create $modelNameLocal -f Modelfile-$modelNameLocal"
            $createProcess = Start-Process -FilePath $OllamaExe -ArgumentList $createArgs -Wait -NoNewWindow -PassThru
            Pop-Location
            
            if ($createProcess.ExitCode -eq 0) {
                Write-Host "      Import complete!" -ForegroundColor Green
                $m.Tag = $modelNameLocal
            } else {
                throw "Exit code $($createProcess.ExitCode)"
            }
        } catch {
            Write-Host "      FAILED to import custom model: $fileName" -ForegroundColor Red
            $downloadErrors += $m.Name
        }
        continue
    }

    # --- Check if standard Ollama model already exists ---
    $showResult = & $OllamaExe show $($m.Tag) 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n  ($idx/$($SelectedModels.Count)) " -ForegroundColor Green -NoNewline
        Write-Host ("$([char]0x2705) {0} [{1}] already pulled - skipping!" -f $m.Name, $m.Tag) -ForegroundColor Green
        $idx++
        continue
    }

    Write-Host "`n  ($idx/$($SelectedModels.Count)) Pulling $($m.Name) [$($m.Tag)]..." -ForegroundColor Yellow
    Write-Host "      Do not close this window! Download may take a while depending on bandwidth." -ForegroundColor Magenta
    $idx++
    
    try {
        $pullArgs = "pull $($m.Tag)"
        $pullProcess = Start-Process -FilePath $OllamaExe -ArgumentList $pullArgs -Wait -NoNewWindow -PassThru
        if ($pullProcess.ExitCode -ne 0) { throw "Exit code $($pullProcess.ExitCode)" }
        Write-Host "      Pull complete!" -ForegroundColor Green
    } catch {
        Write-Host "      FAILED to pull model: $($m.Tag)" -ForegroundColor Red
        $downloadErrors += $m.Name
    }
}

Write-Host "`n      Stopping background Ollama server..." -ForegroundColor DarkGray
Stop-Process -Id $ServerProcess.Id -Force -ErrorAction SilentlyContinue

# Record Models for the Dashboard
$installedList = $SelectedModels | ForEach-Object { "$($_.Tag)|$($_.Name)|$($_.Label)" }
if (Test-Path "$ModelsDir\installed-models.txt") {
    $existing = Get-Content "$ModelsDir\installed-models.txt"
    $installedList = ($existing + $installedList) | Select-Object -Unique
}
Set-Content -Path "$ModelsDir\installed-models.txt" -Value ($installedList -join "`n") -Force -Encoding UTF8

Write-Host "`n[5/5] Finalizing Configurations..." -ForegroundColor Yellow

$firstModelTag = $SelectedModels[0].Tag
$configContent = "AI_PROVIDER=ollama`nCLAUDE_CODE_USE_OPENAI=1`nOPENAI_API_KEY=ollama`nOPENAI_BASE_URL=http://localhost:11434/v1`nOPENAI_MODEL=$firstModelTag`nAI_DISPLAY_MODEL=$firstModelTag"
Set-Content -Path $EnvFile -Value $configContent -Force -Encoding Ascii
Write-Host "      Default Model set to: $firstModelTag" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($downloadErrors.Count -gt 0) { Write-Host "   SETUP COMPLETE (with some download errors)" -ForegroundColor Yellow }
else { Write-Host "   SETUP COMPLETE! LOCAL AI AGENTS ARE READY!" -ForegroundColor Green }
Write-Host "==========================================================" -ForegroundColor Cyan
