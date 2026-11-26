#Requires -Version 5.1
<#
.SYNOPSIS
    Pipeline automatizado de versionamento, validação headless e exportação de builds
    Windows (.exe/.zip), Android (.apk) e Launcher (.exe) para o projeto Magnata do Pampa.
#>

[CmdletBinding()]
param(
    [string[]]$Targets = @("Windows", "Android"),
    [string]$Version = "",
    [switch]$BumpPatch,
    [switch]$BumpMinor,
    [switch]$NoBump,
    [string]$GitHubRepo = "",
    [string]$ReleaseNotes = "",
    [switch]$DebugBuild,
    [switch]$CopyToMdp,
    [switch]$SkipValidation,
    [switch]$PublishGitHubRelease
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
                throw "Alvo invalido '$t'. Valores aceitos: All, Windows, Android, Launcher."
            }
            if ($match -eq "All") {
                [void]$set.Add("Windows")
                [void]$set.Add("Android")
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

# Garantir que nenhuma instancia pesada do Godot esteja aberta antes de exportar
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

# 1. Ler e atualizar data/version.json
Write-Step "1/5 Atualizando versao do projeto e presets"
$VerObj = [ordered]@{
    product_name  = "Magnata do Pampa"
    version       = "0.8.0"
    build_number  = 8
    channel       = "stable"
    github_repo   = ""
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

# Sincronizar project.godot
$pgContent = [System.IO.File]::ReadAllText($ProjectGodotPath, $Utf8NoBom)
if ($pgContent -match '(?m)^config/version=') {
    $pgContent = [regex]::Replace($pgContent, '(?m)^config/version="[^"]*"', "config/version=`"$($VerObj.version)`"")
} else {
    $pgContent = [regex]::Replace($pgContent, '(?m)^(config/name="[^"]*"\r?\n)', "`$1config/version=`"$($VerObj.version)`"`r`n", 1)
}
[System.IO.File]::WriteAllText($ProjectGodotPath, $pgContent, $Utf8NoBom)

# Sincronizar export_presets.cfg
$epContent = [System.IO.File]::ReadAllText($ExportPresetsPath, $Utf8NoBom)
$winFileVer = "$($VerObj.version).$($VerObj.build_number)"
$epContent = [regex]::Replace($epContent, '(?m)^application/file_version="[^"]*"', "application/file_version=`"$winFileVer`"")
$epContent = [regex]::Replace($epContent, '(?m)^application/product_version="[^"]*"', "application/product_version=`"$($VerObj.version)`"")
$epContent = [regex]::Replace($epContent, '(?m)^version/code=\d+', "version/code=$($VerObj.build_number)")
$epContent = [regex]::Replace($epContent, '(?m)^version/name="[^"]*"', "version/name=`"$($VerObj.version)`"")
[System.IO.File]::WriteAllText($ExportPresetsPath, $epContent, $Utf8NoBom)

# Sincronizar github_repo no Launcher se informado
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
    launcher              = $null
}

# Copiar version.json atualizado para latest/ e release dir
Copy-Item -LiteralPath $VersionJsonPath -Destination (Join-Path $LatestDir "version.json") -Force
Copy-Item -LiteralPath $VersionJsonPath -Destination (Join-Path $ReleaseVersionDir "version.json") -Force

# 3. Exportacao Windows (.exe + .zip)
if ($ResolvedTargets -contains "Windows") {
    Write-Step "3/5 Exportando Windows Desktop (.exe + pacote .zip)"
    $WinExeLatest = Join-Path $LatestDir "MagnataDoPampa.exe"
    $WinZipName   = "MagnataDoPampa-Windows-v$($VerObj.version).zip"
    $WinZipLatest = Join-Path $LatestDir $WinZipName
    $WinLog       = Join-Path $BuildsRoot "windows_export_cli.log"
    $ExportFlag   = if ($DebugBuild) { "--export-debug" } else { "--export-release" }

    if (Test-Path -LiteralPath $WinExeLatest) { Remove-Item -LiteralPath $WinExeLatest -Force -ErrorAction SilentlyContinue }
    $winCode = Invoke-GodotCli $GodotExe @("--path", $ProjectDir, $ExportFlag, "Windows Desktop", $WinExeLatest) $WinLog
    if ($winCode -ne 0 -or -not (Test-Path -LiteralPath $WinExeLatest)) {
        throw "Exportacao Windows falhou (codigo $winCode). Consulte $WinLog"
    }

    if (Test-Path -LiteralPath $WinZipLatest) { Remove-Item -LiteralPath $WinZipLatest -Force -ErrorAction SilentlyContinue }
    Compress-Archive -Path @($WinExeLatest, (Join-Path $LatestDir "version.json")) -DestinationPath $WinZipLatest -CompressionLevel Optimal -Force

    Copy-Item -LiteralPath $WinExeLatest -Destination (Join-Path $ReleaseVersionDir "MagnataDoPampa.exe") -Force
    Copy-Item -LiteralPath $WinZipLatest -Destination (Join-Path $ReleaseVersionDir $WinZipName) -Force

    $exeHash = (Get-FileHash -LiteralPath $WinExeLatest -Algorithm SHA256).Hash.ToLower()
    $zipHash = (Get-FileHash -LiteralPath $WinZipLatest -Algorithm SHA256).Hash.ToLower()
    $exeSize = (Get-Item -LiteralPath $WinExeLatest).Length
    $zipSize = (Get-Item -LiteralPath $WinZipLatest).Length

    $Manifest.windows = [ordered]@{
        asset_name   = $WinZipName
        exe_name     = "MagnataDoPampa.exe"
        sha256_zip   = $zipHash
        sha256_exe   = $exeHash
        size_zip     = $zipSize
        size_exe     = $exeSize
        debug_build  = [bool]$DebugBuild
    }
    Write-Ok "Windows exportado: $WinExeLatest ($([Math]::Round($exeSize / 1MB, 2)) MB) + $WinZipName"
} else {
    Write-Info "3/5 Exportacao Windows nao solicitada neste comando."
}

# 4. Exportacao Android (.apk)
if ($ResolvedTargets -contains "Android") {
    Write-Step "4/5 Exportando Android (.apk)"
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
        asset_name  = $ApkName
        sha256      = $apkHash
        size_bytes  = $apkSize
        package_id  = "com.rzgames.magnatadopampa"
        version_code = [int]$VerObj.build_number
    }
    Write-Ok "Android APK exportado: $ApkVersioned ($([Math]::Round($apkSize / 1MB, 2)) MB)"
} else {
    Write-Info "4/5 Exportacao Android nao solicitada neste comando."
}

# 5. Exportacao do Launcher (opcional / Target Launcher)
if ($ResolvedTargets -contains "Launcher") {
    Write-Step "5/5 Exportando Launcher Inicial (.exe)"
    if (-not (Test-Path -LiteralPath (Join-Path $LauncherDir "project.godot"))) {
        throw "Projeto launcher/ nao encontrado em $LauncherDir"
    }
    $LauncherImpLog = Join-Path $BuildsRoot "launcher_import.log"
    $lImpCode = Invoke-GodotCli $GodotExe @("--path", $LauncherDir, "--import", "--quit") $LauncherImpLog
    if ($lImpCode -ne 0) {
        throw "Import do Launcher falhou (codigo $lImpCode). Consulte $LauncherImpLog"
    }

    $LauncherExeLatest = Join-Path $LatestDir "MagnataDoPampaLauncher.exe"
    $LauncherZipName   = "MagnataDoPampaLauncher-Windows-v$($VerObj.version).zip"
    $LauncherZipLatest = Join-Path $LatestDir $LauncherZipName
    $LauncherLog       = Join-Path $BuildsRoot "launcher_export_cli.log"
    $LExportFlag       = if ($DebugBuild) { "--export-debug" } else { "--export-release" }

    if (Test-Path -LiteralPath $LauncherExeLatest) { Remove-Item -LiteralPath $LauncherExeLatest -Force -ErrorAction SilentlyContinue }
    $lCode = Invoke-GodotCli $GodotExe @("--path", $LauncherDir, $LExportFlag, "Windows Desktop", $LauncherExeLatest) $LauncherLog
    if ($lCode -ne 0 -or -not (Test-Path -LiteralPath $LauncherExeLatest)) {
        throw "Exportacao do Launcher falhou (codigo $lCode). Consulte $LauncherLog"
    }

    $LauncherFilesToZip = @($LauncherExeLatest)
    if (Test-Path -LiteralPath $LauncherConfigPath) {
        Copy-Item -LiteralPath $LauncherConfigPath -Destination (Join-Path $LatestDir "launcher_config.json") -Force
        $LauncherFilesToZip += (Join-Path $LatestDir "launcher_config.json")
    }
    if (Test-Path -LiteralPath $LauncherZipLatest) { Remove-Item -LiteralPath $LauncherZipLatest -Force -ErrorAction SilentlyContinue }
    Compress-Archive -Path $LauncherFilesToZip -DestinationPath $LauncherZipLatest -CompressionLevel Optimal -Force

    Copy-Item -LiteralPath $LauncherExeLatest -Destination (Join-Path $ReleaseVersionDir "MagnataDoPampaLauncher.exe") -Force
    Copy-Item -LiteralPath $LauncherZipLatest -Destination (Join-Path $ReleaseVersionDir $LauncherZipName) -Force

    $lExeHash = (Get-FileHash -LiteralPath $LauncherExeLatest -Algorithm SHA256).Hash.ToLower()
    $lExeSize = (Get-Item -LiteralPath $LauncherExeLatest).Length

    $Manifest.launcher = [ordered]@{
        asset_name = $LauncherZipName
        exe_name   = "MagnataDoPampaLauncher.exe"
        sha256_exe = $lExeHash
        size_exe   = $lExeSize
    }
    Write-Ok "Launcher exportado: $LauncherExeLatest ($([Math]::Round($lExeSize / 1MB, 2)) MB)"
} else {
    Write-Info "5/5 Exportacao do Launcher nao solicitada neste comando."
}

# Salvar manifest.json
$ManifestJsonStr = ($Manifest | ConvertTo-Json -Depth 6) + "`r`n"
$ManifestLatestPath  = Join-Path $LatestDir "manifest.json"
$ManifestReleasePath = Join-Path $ReleaseVersionDir "manifest.json"
[System.IO.File]::WriteAllText($ManifestLatestPath, $ManifestJsonStr, $Utf8NoBom)
[System.IO.File]::WriteAllText($ManifestReleasePath, $ManifestJsonStr, $Utf8NoBom)
Write-Ok "Manifest gerado: $ManifestLatestPath"

# Copiar opcionalmente para C:\Projetos\MDP
if ($CopyToMdp) {
    $MdpDir = Join-Path (Split-Path -Parent $WorkspaceRoot) "MDP"
    if (-not (Test-Path -LiteralPath $MdpDir)) { New-Item -ItemType Directory -Path $MdpDir -Force | Out-Null }
    if (Test-Path (Join-Path $LatestDir "MagnataDoPampa.exe")) {
        Copy-Item -LiteralPath (Join-Path $LatestDir "MagnataDoPampa.exe") -Destination (Join-Path $MdpDir "MagnataDoPampa.exe") -Force
        Copy-Item -LiteralPath (Join-Path $LatestDir "version.json") -Destination (Join-Path $MdpDir "version.json") -Force
    }
    if (Test-Path (Join-Path $LatestDir "MagnataDoPampa.apk")) {
        Copy-Item -LiteralPath (Join-Path $LatestDir "MagnataDoPampa.apk") -Destination (Join-Path $MdpDir "mdp.apk") -Force
    }
    if (Test-Path (Join-Path $LatestDir "MagnataDoPampaLauncher.exe")) {
        Copy-Item -LiteralPath (Join-Path $LatestDir "MagnataDoPampaLauncher.exe") -Destination (Join-Path $MdpDir "MagnataDoPampaLauncher.exe") -Force
    }
    Write-Ok "Arquivos copiados para $MdpDir"
}

# Publicar opcionalmente no GitHub Releases via gh CLI
if ($PublishGitHubRelease) {
    Write-Step "Publicando Release v$($VerObj.version) no GitHub Releases"
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghCmd) {
        throw "GitHub CLI (gh) nao encontrado no PATH para -PublishGitHubRelease."
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
    $notesText = if ([string]::IsNullOrWhiteSpace($VerObj.release_notes)) { "Release v$($VerObj.version) (build $($VerObj.build_number))" } else { $VerObj.release_notes }
    & $ghCmd.Source release create ("v" + $VerObj.version) @AssetsToUpload @repoFlag --title "Magnata do Pampa v$($VerObj.version)" --notes $notesText
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao publicar release no GitHub (codigo $LASTEXITCODE)."
    }
    Write-Ok "Release v$($VerObj.version) publicada no GitHub!"
}

Write-Step "Resumo da Automacao de Build"
Write-Host "Versao       : v$($VerObj.version) (build $($VerObj.build_number))"
Write-Host "Pasta Latest : $LatestDir"
Write-Host "Release Dir  : $ReleaseVersionDir"
Write-Host "Manifest     : $ManifestLatestPath"
