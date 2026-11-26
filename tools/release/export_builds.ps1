#Requires -Version 5.1
<#
.SYNOPSIS
    Pipeline automatizado de versionamento, validação headless e exportação unificada
    para Windows (Launcher + Jogo em pacote único .zip) e Android (.apk).
#>

[CmdletBinding()]
param(
    [string[]]$Targets = @("All"),
    [string]$Version = "",
    [switch]$BumpPatch,
    [switch]$BumpMinor,
    [switch]$NoBump,
    [string]$GitHubRepo = "",
    [string]$ReleaseNotes = "",
    [switch]$DebugBuild,
    [switch]$CopyToMdp,
    [switch]$SkipValidation,
    [switch]$PublishGitHubRelease,
    [switch]$SkipGitHubRelease
)

$ErrorActionPreference = "Stop"

$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir    = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$WorkspaceRoot = Split-Path -Parent $ProjectDir
$LauncherDir   = Join-Path $ProjectDir "tools\launcher"
$BuildsRoot    = Join-Path $ProjectDir "builds"
$LatestDir     = Join-Path $BuildsRoot "latest"
$ReleasesDir   = Join-Path $BuildsRoot "releases"

$VersionJsonPath    = Join-Path $ProjectDir "data\version.json"
$ProjectGodotPath   = Join-Path $ProjectDir "project.godot"
$ExportPresetsPath  = Join-Path $ProjectDir "export_presets.cfg"
$LauncherConfigPath = Join-Path $LauncherDir "launcher_config.json"

function Write-Step([string]$Msg) { Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok([string]$Msg)   { Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host "[AVISO] $Msg" -ForegroundColor Yellow }
function Write-Info([string]$Msg) { Write-Host "[INFO]  $Msg" -ForegroundColor Gray }

function Resolve-TargetList([string[]]$RawTargets) {
    $valid = @("All", "Windows", "Android", "Launcher")
    $set = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::OrdinalIgnoreCase)
    foreach ($raw in $RawTargets) {
        foreach ($part in ($raw -split "[,;\s]+")) {
            $t = $part.Trim()
            if ([string]::IsNullOrWhiteSpace($t)) { continue }
            $match = $valid | Where-Object { $_ -ieq $t } | Select-Object -First 1
            if (-not $match) {
                throw "Alvo invalido '$t'. Valores aceitos: All, Windows, Android."
            }
            if ($match -eq "All") {
                [void]$set.Add("Windows")
                [void]$set.Add("Launcher")
                [void]$set.Add("Android")
            } elseif ($match -eq "Windows" -or $match -eq "Launcher") {
                # Regra oficial: Windows sempre e distribuido junto com o Launcher
                [void]$set.Add("Windows")
                [void]$set.Add("Launcher")
            } else {
                [void]$set.Add($match)
            }
        }
    }
    return @($set)
}

function Find-GodotExecutable {
    $candidates = @(
        "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
    )
    $steamMatch = Get-ChildItem "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\" -Filter "*godot*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*console*" } |
        Select-Object -First 1 -ExpandProperty FullName
    if ($steamMatch) { $candidates = @($steamMatch) + $candidates }

    foreach ($cmdName in @("godot4", "godot", "godot.exe")) {
        $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
        if ($cmd) { $candidates += $cmd.Source }
    }

    foreach ($c in ($candidates | Select-Object -Unique)) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }
    throw "Executavel do Godot 4.7 nao encontrado."
}

function Find-GhExecutable {
    $candidates = @()
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { $candidates += $cmd.Source }
    $candidates += @(
        (Join-Path $env:ProgramFiles "GitHub CLI\gh.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "GitHub CLI\gh.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\GitHub CLI\gh.exe")
    )
    foreach ($c in ($candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $c) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }
    return $null
}

function Find-AndroidEnvironment {
    $sdkCandidates = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk"),
        "C:\Android\Sdk",
        "C:\Program Files\Android\Sdk"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    $sdkPath = $null
    foreach ($cand in $sdkCandidates) {
        if (Test-Path -LiteralPath $cand) {
            if ((Test-Path (Join-Path $cand "platforms")) -or (Test-Path (Join-Path $cand "platform-tools"))) {
                $sdkPath = (Resolve-Path -LiteralPath $cand).Path
                break
            }
        }
    }

    $javaCandidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) { $javaCandidates.Add($env:JAVA_HOME) }
    $javaCandidates.Add("C:\Program Files\Android\Android Studio\jbr")
    foreach ($root in @("C:\Program Files\Eclipse Adoptium", "C:\Program Files\Microsoft", "C:\Program Files\Java", "C:\Program Files\Temurin")) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                ForEach-Object { $javaCandidates.Add($_.FullName) }
        }
    }

    $javaPath = $null
    foreach ($jc in ($javaCandidates | Select-Object -Unique)) {
        if ($jc -and (Test-Path (Join-Path $jc "bin\java.exe")) -and (Test-Path (Join-Path $jc "bin\keytool.exe"))) {
            $javaPath = (Resolve-Path -LiteralPath $jc).Path
            break
        }
    }

    return @{
        AndroidSdk = $sdkPath
        JavaHome   = $javaPath
    }
}

function Invoke-GodotCli([string]$GodotExe, [string[]]$CliArgs, [string]$LogFilePath) {
    $logDir = Split-Path -Parent $LogFilePath
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $LogFilePath) {
        Remove-Item -LiteralPath $LogFilePath -Force -ErrorAction SilentlyContinue
    }
    $rawArgs = @("--headless", "--log-file", $LogFilePath) + $CliArgs
    $quotedArgs = @()
    foreach ($arg in $rawArgs) {
        if ($arg -match '\s') {
            $quotedArgs += ('"' + $arg.Replace('"', '\"') + '"')
        } else {
            $quotedArgs += $arg
        }
    }
    $proc = Start-Process -FilePath $GodotExe -ArgumentList $quotedArgs -NoNewWindow -Wait -PassThru
    return $proc.ExitCode
}

$ResolvedTargets = Resolve-TargetList $Targets
$GodotExe = Find-GodotExecutable
Write-Ok "Godot encontrado: $GodotExe"
Write-Info "Alvos selecionados: $($ResolvedTargets -join ', ')"

$runningGodot = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match "(?i)^godot" }
if ($runningGodot) {
    Write-Warn "Ha instancia do Godot em execucao (PID: $($runningGodot.Id -join ', ')). Prefira fechar o editor antes de exportar para respeitar o limite de 1 instancia por vez."
}

if (-not (Test-Path -LiteralPath $LatestDir)) {
    New-Item -ItemType Directory -Path $LatestDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $ReleasesDir)) {
    New-Item -ItemType Directory -Path $ReleasesDir -Force | Out-Null
}

# Limpar zips legados separados de launcher para manter bundle unico no Windows
Get-ChildItem -LiteralPath $LatestDir -Filter "MagnataDoPampaLauncher-Windows-*.zip" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

# 1. Ler e atualizar data/version.json
Write-Step "1/5 Atualizando versao do projeto e presets"
$VerObj = [ordered]@{
    product_name  = "Magnata do Pampa"
    version       = "0.8.0"
    build_number  = 8
    channel       = "stable"
    github_repo   = "rzanca/MagnataDoPampa"
    release_notes = ""
    built_at      = ""
    git_commit    = ""
}

if (Test-Path -LiteralPath $VersionJsonPath) {
    $parsedVer = Get-Content -LiteralPath $VersionJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($parsedVer.product_name) { $VerObj.product_name = [string]$parsedVer.product_name }
    if ($parsedVer.version) { $VerObj.version = [string]$parsedVer.version }
    if ($null -ne $parsedVer.build_number) { $VerObj.build_number = [int]$parsedVer.build_number }
    if ($parsedVer.channel) { $VerObj.channel = [string]$parsedVer.channel }
    if ($parsedVer.github_repo) { $VerObj.github_repo = [string]$parsedVer.github_repo }
    if ($parsedVer.release_notes) { $VerObj.release_notes = [string]$parsedVer.release_notes }
}

if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $VerObj.version = $Version.TrimStart("v", "V").Trim()
} elseif ($BumpMinor) {
    $parts = $VerObj.version.Split(".")
    $maj = if ($parts.Length -ge 1) { [int]$parts[0] } else { 0 }
    $min = if ($parts.Length -ge 2) { [int]$parts[1] + 1 } else { 1 }
    $VerObj.version = "$maj.$min.0"
} elseif ($BumpPatch) {
    $parts = $VerObj.version.Split(".")
    $maj = if ($parts.Length -ge 1) { [int]$parts[0] } else { 0 }
    $min = if ($parts.Length -ge 2) { [int]$parts[1] } else { 8 }
    $pat = if ($parts.Length -ge 3) { [int]$parts[2] + 1 } else { 1 }
    $VerObj.version = "$maj.$min.$pat"
}

if (-not $NoBump) {
    $VerObj.build_number = [int]$VerObj.build_number + 1
}

if (-not [string]::IsNullOrWhiteSpace($GitHubRepo)) {
    $VerObj.github_repo = $GitHubRepo.Trim()
}
if (-not [string]::IsNullOrWhiteSpace($ReleaseNotes)) {
    $VerObj.release_notes = $ReleaseNotes.Trim()
}

$GitSha = ""
try {
    $GitSha = (git -C $ProjectDir rev-parse --short HEAD 2>$null | Out-String).Trim()
} catch {
    $GitSha = ""
}
$BuiltAtIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$VerObj.built_at = $BuiltAtIso
$VerObj.git_commit = $GitSha

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$VersionJsonStr = ($VerObj | ConvertTo-Json -Depth 5) + "`r`n"
[System.IO.File]::WriteAllText($VersionJsonPath, $VersionJsonStr, $Utf8NoBom)

# Sincronizar project.godot principal e do Launcher
$pgContent = [System.IO.File]::ReadAllText($ProjectGodotPath, $Utf8NoBom)
if ($pgContent -match '(?m)^config/version=') {
    $pgContent = [regex]::Replace($pgContent, '(?m)^config/version="[^"]*"', "config/version=`"$($VerObj.version)`"")
} else {
    $pgContent = [regex]::Replace($pgContent, '(?m)^(config/name="[^"]*"\r?\n)', "`$1config/version=`"$($VerObj.version)`"`r`n", 1)
}
[System.IO.File]::WriteAllText($ProjectGodotPath, $pgContent, $Utf8NoBom)

$LauncherPgPath = Join-Path $LauncherDir "project.godot"
if (Test-Path -LiteralPath $LauncherPgPath) {
    $lpg = [System.IO.File]::ReadAllText($LauncherPgPath, $Utf8NoBom)
    if ($lpg -match '(?m)^config/version=') {
        $lpg = [regex]::Replace($lpg, '(?m)^config/version="[^"]*"', "config/version=`"$($VerObj.version)`"")
        [System.IO.File]::WriteAllText($LauncherPgPath, $lpg, $Utf8NoBom)
    }
}

# Sincronizar export_presets.cfg (Jogo + Launcher)
$epContent = [System.IO.File]::ReadAllText($ExportPresetsPath, $Utf8NoBom)
$winFileVer = "$($VerObj.version).$($VerObj.build_number)"
$epContent = [regex]::Replace($epContent, '(?m)^application/file_version="[^"]*"', "application/file_version=`"$winFileVer`"")
$epContent = [regex]::Replace($epContent, '(?m)^application/product_version="[^"]*"', "application/product_version=`"$($VerObj.version)`"")
$epContent = [regex]::Replace($epContent, '(?m)^version/code=\d+', "version/code=$($VerObj.build_number)")
$epContent = [regex]::Replace($epContent, '(?m)^version/name="[^"]*"', "version/name=`"$($VerObj.version)`"")
[System.IO.File]::WriteAllText($ExportPresetsPath, $epContent, $Utf8NoBom)

$LauncherEpPath = Join-Path $LauncherDir "export_presets.cfg"
if (Test-Path -LiteralPath $LauncherEpPath) {
    $lep = [System.IO.File]::ReadAllText($LauncherEpPath, $Utf8NoBom)
    $lep = [regex]::Replace($lep, '(?m)^application/file_version="[^"]*"', "application/file_version=`"$winFileVer`"")
    $lep = [regex]::Replace($lep, '(?m)^application/product_version="[^"]*"', "application/product_version=`"$($VerObj.version)`"")
    [System.IO.File]::WriteAllText($LauncherEpPath, $lep, $Utf8NoBom)
}

if (-not [string]::IsNullOrWhiteSpace($VerObj.github_repo) -and (Test-Path -LiteralPath $LauncherConfigPath)) {
    $lCfg = Get-Content -LiteralPath $LauncherConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $lCfg.github_repo = $VerObj.github_repo
    [System.IO.File]::WriteAllText($LauncherConfigPath, (($lCfg | ConvertTo-Json -Depth 5) + "`r`n"), $Utf8NoBom)
}

Write-Ok "Versao sincronizada: v$($VerObj.version) (build $($VerObj.build_number), commit $GitSha)"

$ReleaseVersionDir = Join-Path $ReleasesDir ("v" + $VerObj.version)
if (-not (Test-Path -LiteralPath $ReleaseVersionDir)) {
    New-Item -ItemType Directory -Path $ReleaseVersionDir -Force | Out-Null
}

# 2. Validacao Headless antes de exportar
if (-not $SkipValidation) {
    Write-Step "2/5 Validando projeto principal em modo Headless (1 instancia por vez)"
    $impLog = Join-Path $BuildsRoot "game_import.log"
    $impCode = Invoke-GodotCli $GodotExe @("--path", $ProjectDir, "--import", "--quit") $impLog
    if ($impCode -ne 0) {
        throw "Godot --import falhou (codigo $impCode). Verifique $impLog"
    }

    $smokeLog = Join-Path $BuildsRoot "game_smoke.log"
    $smokeCode = Invoke-GodotCli $GodotExe @("--path", $ProjectDir, "--quit-after", "120") $smokeLog
    $smokeRaw = if (Test-Path -LiteralPath $smokeLog) { Get-Content -LiteralPath $smokeLog -Encoding UTF8 } else { @() }
    $gameErrors = $smokeRaw | Where-Object {
        ($_ -match "SCRIPT ERROR:|Parse Error:") -and
        ($_ -notmatch "addons/gamedev_ai") -and
        ($_ -notmatch "ObjectDB instances were leaked") -and
        ($_ -notmatch "resources still in use at exit")
    }
    if ($smokeCode -ne 0 -or $gameErrors) {
        if ($gameErrors) { $gameErrors | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
        throw "Smoke test do jogo falhou (codigo $smokeCode). Consulte $smokeLog"
    }
    Write-Ok "Validacao Headless aprovada (0 erros de script)."
} else {
    Write-Warn "2/5 Validacao Headless ignorada (-SkipValidation)."
}

$Manifest = [ordered]@{
    product_name          = $VerObj.product_name
    tag_name              = "v$($VerObj.version)"
    version               = $VerObj.version
    build_number          = [int]$VerObj.build_number
    channel               = $VerObj.channel
    min_supported_version = "0.8.0"
    git_commit            = $GitSha
    released_at           = $BuiltAtIso
    github_repo           = $VerObj.github_repo
    notes                 = $VerObj.release_notes
    windows               = $null
    android               = $null
}

Copy-Item -LiteralPath $VersionJsonPath -Destination (Join-Path $LatestDir "version.json") -Force
Copy-Item -LiteralPath $VersionJsonPath -Destination (Join-Path $ReleaseVersionDir "version.json") -Force

# 3. Exportacao Windows Unificada (Jogo + Launcher obrigatorios juntos)
if ($ResolvedTargets -contains "Windows") {
    Write-Step "3/5 Exportando Windows Desktop (Jogo + Launcher em pacote unico)"
    if (-not (Test-Path -LiteralPath (Join-Path $LauncherDir "project.godot"))) {
        throw "Projeto tools/launcher/ nao encontrado em $LauncherDir"
    }

    $WinExeRelease      = Join-Path $ReleaseVersionDir "MagnataDoPampa.exe"
    $WinExeLatest       = Join-Path $LatestDir "MagnataDoPampa.exe"
    $WinLog             = Join-Path $BuildsRoot "windows_export_cli.log"
    $ExportFlag         = if ($DebugBuild) { "--export-debug" } else { "--export-release" }

    if (Test-Path -LiteralPath $WinExeRelease) { Remove-Item -LiteralPath $WinExeRelease -Force -ErrorAction SilentlyContinue }
    $winCode = Invoke-GodotCli $GodotExe @("--path", $ProjectDir, $ExportFlag, "Windows Desktop", $WinExeRelease) $WinLog
    if ($winCode -ne 0 -or -not (Test-Path -LiteralPath $WinExeRelease)) {
        throw "Exportacao Windows do jogo falhou (codigo $winCode). Consulte $WinLog"
    }

    Write-Step "4/5 Exportando Launcher Inicial e empacotando bundle unico Windows"
    $LauncherImpLog = Join-Path $BuildsRoot "launcher_import.log"
    $lImpCode = Invoke-GodotCli $GodotExe @("--path", $LauncherDir, "--import", "--quit") $LauncherImpLog
    if ($lImpCode -ne 0) {
        throw "Import do Launcher falhou (codigo $lImpCode). Consulte $LauncherImpLog"
    }

    $LauncherExeRelease = Join-Path $ReleaseVersionDir "MagnataDoPampaLauncher.exe"
    $LauncherExeLatest  = Join-Path $LatestDir "MagnataDoPampaLauncher.exe"
    $LauncherLog        = Join-Path $BuildsRoot "launcher_export_cli.log"
    if (Test-Path -LiteralPath $LauncherExeRelease) { Remove-Item -LiteralPath $LauncherExeRelease -Force -ErrorAction SilentlyContinue }
    $lCode = Invoke-GodotCli $GodotExe @("--path", $LauncherDir, $ExportFlag, "Windows Desktop", $LauncherExeRelease) $LauncherLog
    if ($lCode -ne 0 -or -not (Test-Path -LiteralPath $LauncherExeRelease)) {
        throw "Exportacao do Launcher falhou (codigo $lCode). Consulte $LauncherLog"
    }

    $BundleItems = @($LauncherExeRelease, $WinExeRelease, (Join-Path $ReleaseVersionDir "version.json"))
    if (Test-Path -LiteralPath $LauncherConfigPath) {
        Copy-Item -LiteralPath $LauncherConfigPath -Destination (Join-Path $ReleaseVersionDir "launcher_config.json") -Force
        Copy-Item -LiteralPath $LauncherConfigPath -Destination (Join-Path $LatestDir "launcher_config.json") -Force
        $BundleItems += (Join-Path $ReleaseVersionDir "launcher_config.json")
    }

    $WinZipName     = "MagnataDoPampa-Windows-v$($VerObj.version).zip"
    $WinZipRelease  = Join-Path $ReleaseVersionDir $WinZipName
    $WinZipLatest   = Join-Path $LatestDir $WinZipName
    if (Test-Path -LiteralPath $WinZipRelease) { Remove-Item -LiteralPath $WinZipRelease -Force -ErrorAction SilentlyContinue }
    Compress-Archive -Path $BundleItems -DestinationPath $WinZipRelease -CompressionLevel Optimal -Force

    Copy-Item -LiteralPath $WinZipRelease -Destination $WinZipLatest -Force
    try {
        Copy-Item -LiteralPath $WinExeRelease -Destination $WinExeLatest -Force -ErrorAction Stop
    } catch {
        Write-Warn "Nao foi possivel sobrescrever $WinExeLatest porque o jogo esta aberto. O pacote ZIP e releases/v$($VerObj.version) ja estao atualizados."
    }
    try {
        Copy-Item -LiteralPath $LauncherExeRelease -Destination $LauncherExeLatest -Force -ErrorAction Stop
    } catch {
        Write-Warn "Nao foi possivel sobrescrever $LauncherExeLatest porque o Launcher esta aberto. O pacote ZIP e releases/v$($VerObj.version) ja estao atualizados."
    }

    $exeHash      = (Get-FileHash -LiteralPath $WinExeRelease -Algorithm SHA256).Hash.ToLower()
    $launcherHash = (Get-FileHash -LiteralPath $LauncherExeRelease -Algorithm SHA256).Hash.ToLower()
    $zipHash      = (Get-FileHash -LiteralPath $WinZipRelease -Algorithm SHA256).Hash.ToLower()
    $exeSize      = (Get-Item -LiteralPath $WinExeRelease).Length
    $launcherSize = (Get-Item -LiteralPath $LauncherExeRelease).Length
    $zipSize      = (Get-Item -LiteralPath $WinZipRelease).Length

    $Manifest.windows = [ordered]@{
        asset_name          = $WinZipName
        launcher_exe_name   = "MagnataDoPampaLauncher.exe"
        exe_name            = "MagnataDoPampa.exe"
        sha256_zip          = $zipHash
        sha256_exe          = $exeHash
        sha256_launcher_exe = $launcherHash
        size_zip            = $zipSize
        size_exe            = $exeSize
        size_launcher_exe   = $launcherSize
        debug_build         = [bool]$DebugBuild
    }
    Write-Ok "Pacote unico Windows gerado: $WinZipName ($([Math]::Round($zipSize / 1MB, 2)) MB, Launcher + Jogo)"
} else {
    Write-Info "3/5 e 4/5 Exportacao Windows + Launcher nao solicitada neste comando."
}

# 5. Exportacao Android (.apk)
if ($ResolvedTargets -contains "Android") {
    Write-Step "5/5 Exportando Android (.apk)"
    $AndroidEnv = Find-AndroidEnvironment
    if (-not $AndroidEnv.AndroidSdk -or -not $AndroidEnv.JavaHome) {
        throw "Requisitos Android nao encontrados (AndroidSdk=$($AndroidEnv.AndroidSdk), JavaHome=$($AndroidEnv.JavaHome))."
    }
    $env:ANDROID_HOME     = $AndroidEnv.AndroidSdk
    $env:ANDROID_SDK_ROOT = $AndroidEnv.AndroidSdk
    $env:JAVA_HOME        = $AndroidEnv.JavaHome

    $ApkName      = "MagnataDoPampa-v$($VerObj.version).apk"
    $ApkVersioned = Join-Path $LatestDir $ApkName
    $ApkLatest    = Join-Path $LatestDir "MagnataDoPampa.apk"
    $AndroidLog   = Join-Path $BuildsRoot "android_export_cli.log"

    if (Test-Path -LiteralPath $ApkVersioned) { Remove-Item -LiteralPath $ApkVersioned -Force -ErrorAction SilentlyContinue }
    $andCode = Invoke-GodotCli $GodotExe @("--path", $ProjectDir, "--export-debug", "Android", $ApkVersioned) $AndroidLog
    if ($andCode -ne 0 -or -not (Test-Path -LiteralPath $ApkVersioned)) {
        throw "Exportacao Android falhou (codigo $andCode). Consulte $AndroidLog"
    }

    Copy-Item -LiteralPath $ApkVersioned -Destination $ApkLatest -Force
    Copy-Item -LiteralPath $ApkVersioned -Destination (Join-Path $ReleaseVersionDir $ApkName) -Force

    $apkHash = (Get-FileHash -LiteralPath $ApkVersioned -Algorithm SHA256).Hash.ToLower()
    $apkSize = (Get-Item -LiteralPath $ApkVersioned).Length

    $Manifest.android = [ordered]@{
        asset_name   = $ApkName
        sha256       = $apkHash
        size_bytes   = $apkSize
        package_id   = "com.rzgames.magnatadopampa"
        version_code = [int]$VerObj.build_number
    }
    Write-Ok "Android APK exportado: $ApkVersioned ($([Math]::Round($apkSize / 1MB, 2)) MB)"
} else {
    Write-Info "5/5 Exportacao Android nao solicitada neste comando."
}

$ManifestJsonStr = ($Manifest | ConvertTo-Json -Depth 6) + "`r`n"
$ManifestLatestPath  = Join-Path $LatestDir "manifest.json"
$ManifestReleasePath = Join-Path $ReleaseVersionDir "manifest.json"
[System.IO.File]::WriteAllText($ManifestLatestPath, $ManifestJsonStr, $Utf8NoBom)
[System.IO.File]::WriteAllText($ManifestReleasePath, $ManifestJsonStr, $Utf8NoBom)
Write-Ok "Manifest gerado: $ManifestLatestPath"

if ($CopyToMdp) {
    $MdpDir = Join-Path (Split-Path -Parent $WorkspaceRoot) "MDP"
    if (-not (Test-Path -LiteralPath $MdpDir)) { New-Item -ItemType Directory -Path $MdpDir -Force | Out-Null }
    if (Test-Path (Join-Path $LatestDir "MagnataDoPampa.exe")) {
        Copy-Item -LiteralPath (Join-Path $LatestDir "MagnataDoPampa.exe") -Destination (Join-Path $MdpDir "MagnataDoPampa.exe") -Force
        Copy-Item -LiteralPath (Join-Path $LatestDir "version.json") -Destination (Join-Path $MdpDir "version.json") -Force
    }
    if (Test-Path (Join-Path $LatestDir "MagnataDoPampaLauncher.exe")) {
        Copy-Item -LiteralPath (Join-Path $LatestDir "MagnataDoPampaLauncher.exe") -Destination (Join-Path $MdpDir "MagnataDoPampaLauncher.exe") -Force
        if (Test-Path (Join-Path $LatestDir "launcher_config.json")) {
            Copy-Item -LiteralPath (Join-Path $LatestDir "launcher_config.json") -Destination (Join-Path $MdpDir "launcher_config.json") -Force
        }
    }
    if (Test-Path (Join-Path $LatestDir "MagnataDoPampa.apk")) {
        Copy-Item -LiteralPath (Join-Path $LatestDir "MagnataDoPampa.apk") -Destination (Join-Path $MdpDir "mdp.apk") -Force
    }
    Write-Ok "Arquivos copiados para $MdpDir"
}

$ShouldPublishRelease = $true
if ($SkipGitHubRelease) {
    $ShouldPublishRelease = $false
} elseif ($PublishGitHubRelease) {
    $ShouldPublishRelease = $true
}

if ($ShouldPublishRelease) {
    Write-Step "Publicando Release v$($VerObj.version) no GitHub Releases"
    $ghExe = Find-GhExecutable
    if (-not $ghExe) {
        throw "GitHub CLI (gh) nao encontrado no PATH nem em Program Files. Use -SkipGitHubRelease para pular o upload."
    }
    $AssetsToUpload = New-Object System.Collections.Generic.List[string]
    $AssetsToUpload.Add($ManifestReleasePath)
    Get-ChildItem -LiteralPath $ReleaseVersionDir -File | Where-Object { $_.Extension -in @(".zip", ".apk") } | ForEach-Object {
        $AssetsToUpload.Add($_.FullName)
    }
    $repoFlag = @()
    if (-not [string]::IsNullOrWhiteSpace($VerObj.github_repo)) {
        $repoFlag = @("--repo", $VerObj.github_repo)
    }
    $tagName = "v" + $VerObj.version
    $releaseTitle = "Magnata do Pampa $tagName"
    $notesText = if ([string]::IsNullOrWhiteSpace($VerObj.release_notes)) { "Release $tagName (build $($VerObj.build_number))" } else { $VerObj.release_notes }

    & $ghExe release view $tagName @repoFlag *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Release $tagName ja existe no GitHub; atualizando assets (--clobber)..."
        & $ghExe release upload $tagName @AssetsToUpload @repoFlag --clobber
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao atualizar assets da release $tagName no GitHub (codigo $LASTEXITCODE)."
        }
        & $ghExe release edit $tagName @repoFlag --title $releaseTitle --notes $notesText
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao atualizar metadados da release $tagName no GitHub (codigo $LASTEXITCODE)."
        }
    } else {
        & $ghExe release create $tagName @AssetsToUpload @repoFlag --target main --title $releaseTitle --notes $notesText
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao publicar release $tagName no GitHub (codigo $LASTEXITCODE)."
        }
    }
    Write-Ok "Release $tagName publicada no GitHub!"
} else {
    Write-Info "Publicacao no GitHub Releases ignorada (-SkipGitHubRelease)."
}

Write-Step "Resumo da Automacao de Build"
Write-Host "Versao       : v$($VerObj.version) (build $($VerObj.build_number))"
Write-Host "Pasta Latest : $LatestDir"
Write-Host "Release Dir  : $ReleaseVersionDir"
Write-Host "Manifest     : $ManifestLatestPath"
