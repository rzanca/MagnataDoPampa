#Requires -Version 5.1
<#
.SYNOPSIS
    Automates Android Beta export detection, debug.keystore setup, export_presets.cfg update,
    and optional Godot 4.7 CLI export test for Magnata do Pampa.
    Does NOT modify any .tscn files or gameplay scripts.
#>

[CmdletBinding()]
param(
    [switch]$SkipCliExport
)

$ErrorActionPreference = "Stop"

$ProjectDir    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$PresetsPath   = Join-Path $ProjectDir "export_presets.cfg"
$ProjectGodot  = Join-Path $ProjectDir "project.godot"
$BuildsDir     = Join-Path $ProjectDir "builds"
$ApkOutWin     = Join-Path $BuildsDir "latest\MagnataDoPampa-beta.apk"
$ApkOutGodot   = "builds/latest/MagnataDoPampa-beta.apk"

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Ok([string]$Msg)   { Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host "[AVISO] $Msg" -ForegroundColor Yellow }
function Write-Info([string]$Msg) { Write-Host "[INFO]  $Msg" -ForegroundColor Gray }

# ------------------------------------------------------------------
# 1. Detectar Android SDK (API 36, platform-tools, build-tools) e Java/JBR
# ------------------------------------------------------------------
Write-Section "1. Deteccao de Ambiente Android SDK e Java/JBR"

$SdkCandidates = @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    (Join-Path $env:LOCALAPPDATA "Android\Sdk"),
    "C:\Android\Sdk",
    "C:\Program Files\Android\Sdk"
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

$AndroidSdkPath = $null
$FallbackSdkPath = $null
foreach ($cand in $SdkCandidates) {
    if (Test-Path -LiteralPath $cand -ErrorAction SilentlyContinue) {
        $resolved = (Resolve-Path -LiteralPath $cand).Path
        $hasPlatforms = Test-Path -LiteralPath (Join-Path $resolved "platforms") -ErrorAction SilentlyContinue
        $hasTools     = Test-Path -LiteralPath (Join-Path $resolved "platform-tools") -ErrorAction SilentlyContinue
        $hasBuild     = Test-Path -LiteralPath (Join-Path $resolved "build-tools") -ErrorAction SilentlyContinue
        if ($hasPlatforms -or $hasTools -or $hasBuild) {
            $AndroidSdkPath = $resolved
            break
        } elseif (-not $FallbackSdkPath) {
            $FallbackSdkPath = $resolved
        }
    }
}
if (-not $AndroidSdkPath -and $FallbackSdkPath) {
    $AndroidSdkPath = $FallbackSdkPath
}

$HasApi36 = $false
$PlatformToolsOk = $false
$BuildToolsList = @()
$PlatformsList = @()

if ($AndroidSdkPath) {
    Write-Ok "Android SDK encontrado: $AndroidSdkPath"

    $platformsDir = Join-Path $AndroidSdkPath "platforms"
    if (Test-Path -LiteralPath $platformsDir) {
        $PlatformsList = @(Get-ChildItem -LiteralPath $platformsDir -Directory | Select-Object -ExpandProperty Name)
        if ($PlatformsList -contains "android-36") {
            $HasApi36 = $true
            Write-Ok "Plataforma API 36 encontrada: $(Join-Path $platformsDir 'android-36')"
        } else {
            Write-Warn "API 36 (android-36) nao encontrada. Instaladas: $($PlatformsList -join ', ')"
        }
    } else {
        Write-Warn "Pasta 'platforms' ausente no Android SDK."
    }

    $adbPath = Join-Path $AndroidSdkPath "platform-tools\adb.exe"
    if (Test-Path -LiteralPath $adbPath) {
        $PlatformToolsOk = $true
        Write-Ok "platform-tools encontrado: $(Split-Path -Parent $adbPath)"
    } else {
        Write-Warn "platform-tools (adb.exe) nao encontrado em $AndroidSdkPath."
    }

    $btDir = Join-Path $AndroidSdkPath "build-tools"
    if (Test-Path -LiteralPath $btDir) {
        $BuildToolsList = @(Get-ChildItem -LiteralPath $btDir -Directory | Sort-Object Name -Descending | Select-Object -ExpandProperty Name)
        if ($BuildToolsList.Count -gt 0) {
            Write-Ok "build-tools encontrado(s): $($BuildToolsList -join ', ')"
        } else {
            Write-Warn "Nenhum build-tools instalado em $btDir."
        }
    } else {
        Write-Warn "Pasta 'build-tools' ausente no Android SDK."
    }
} else {
    Write-Warn "Android SDK nao encontrado nos caminhos padrao (%LOCALAPPDATA%\Android\Sdk, ANDROID_HOME, etc.)."
}

$JavaCandidates = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) { $JavaCandidates.Add($env:JAVA_HOME) }

$JdkRoots = @(
    "C:\Program Files\Eclipse Adoptium",
    "C:\Program Files\Microsoft",
    "C:\Program Files\Java",
    "C:\Program Files\Zulu",
    "C:\Program Files\Amazon Corretto",
    "C:\Program Files\Temurin"
)
foreach ($root in $JdkRoots) {
    if (Test-Path -LiteralPath $root -ErrorAction SilentlyContinue) {
        $dirs = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($d in $dirs) {
            if ($d.Name -match "17") { $JavaCandidates.Add($d.FullName) }
        }
    }
}
$JavaCandidates.Add("C:\Program Files\Android\Android Studio\jbr")
foreach ($root in $JdkRoots) {
    if (Test-Path -LiteralPath $root -ErrorAction SilentlyContinue) {
        $dirs = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($d in $dirs) {
            if ($d.Name -notmatch "17") { $JavaCandidates.Add($d.FullName) }
        }
    }
}

$JavaHomePath = $null
$KeytoolPath = $null
$JavaExePath = $null
$AllFoundJavas = New-Object System.Collections.Generic.List[string]

foreach ($jc in ($JavaCandidates | Select-Object -Unique)) {
    if ([string]::IsNullOrWhiteSpace($jc)) { continue }
    $kt = Join-Path $jc "bin\keytool.exe"
    $jv = Join-Path $jc "bin\java.exe"
    if ((Test-Path -LiteralPath $kt -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $jv -ErrorAction SilentlyContinue)) {
        $resJc = (Resolve-Path -LiteralPath $jc).Path
        $AllFoundJavas.Add($resJc)
        if (-not $JavaHomePath) {
            $JavaHomePath = $resJc
            $KeytoolPath  = (Resolve-Path -LiteralPath $kt).Path
            $JavaExePath  = (Resolve-Path -LiteralPath $jv).Path
        }
    }
}

if (-not $JavaHomePath) {
    $cmdJava = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($cmdJava) {
        $JavaExePath = $cmdJava.Source
        $binDir = Split-Path -Parent $JavaExePath
        $JavaHomePath = Split-Path -Parent $binDir
        $ktFallback = Join-Path $binDir "keytool.exe"
        if (Test-Path -LiteralPath $ktFallback) { $KeytoolPath = $ktFallback }
    }
}

if ($JavaHomePath) {
    Write-Ok "Java/JBR selecionado: $JavaHomePath"
    if ($AllFoundJavas.Count -gt 1) {
        Write-Info "Outros Java/JBR detectados: $($AllFoundJavas -join ' ; ')"
    }
    try {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $javaVerOut = & $JavaExePath -version 2>&1 | Select-Object -First 2
        $ErrorActionPreference = $prevEap
        foreach ($line in $javaVerOut) {
            Write-Info "  $line"
        }
    } catch {
        Write-Warn "Nao foi possivel consultar java -version: $($_.Exception.Message)"
    }
} else {
    Write-Warn "Java/JBR (JDK 17 ou Android Studio JBR) nao encontrado."
}

# ------------------------------------------------------------------
# 2. Garantir debug.keystore sem sobrescrever se ja existir
# ------------------------------------------------------------------
Write-Section "2. Verificacao/Geracao de debug.keystore"

$DotAndroidDir = Join-Path $env:USERPROFILE ".android"
$KeystorePath  = Join-Path $DotAndroidDir "debug.keystore"
$KeystoreGodot = $KeystorePath.Replace("\", "/")

if (Test-Path -LiteralPath $KeystorePath) {
    $ksInfo = Get-Item -LiteralPath $KeystorePath
    Write-Ok "debug.keystore ja existe e foi preservado sem sobrescrever: $KeystorePath ($($ksInfo.Length) bytes)"
} else {
    if (-not $KeytoolPath) {
        Write-Warn "debug.keystore nao existe e keytool.exe nao foi encontrado para gera-lo."
    } else {
        if (-not (Test-Path -LiteralPath $DotAndroidDir)) {
            New-Item -ItemType Directory -Path $DotAndroidDir -Force | Out-Null
        }
        Write-Info "Gerando debug.keystore (RSA 2048, alias androiddebugkey, senha android)..."
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $ktOut = & $KeytoolPath -genkeypair -v `
            -keystore $KeystorePath `
            -storepass android `
            -alias androiddebugkey `
            -keypass android `
            -keyalg RSA `
            -keysize 2048 `
            -validity 10000 `
            -dname "CN=Android Debug,O=Android,C=US" 2>&1
        $ktCode = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        if ($ktCode -eq 0 -and (Test-Path -LiteralPath $KeystorePath)) {
            Write-Ok "debug.keystore gerado com sucesso em: $KeystorePath"
        } else {
            Write-Warn "Falha ao gerar debug.keystore (codigo $ktCode): $($ktOut -join ' ')"
        }
    }
}

# ------------------------------------------------------------------
# 3. Criar/atualizar magnata-do-pampa/export_presets.cfg
# ------------------------------------------------------------------
Write-Section "3. Configuracao de magnata-do-pampa/export_presets.cfg"

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    throw "Pasta do projeto Godot nao encontrada em $ProjectDir"
}

if (-not (Test-Path -LiteralPath $BuildsDir)) {
    New-Item -ItemType Directory -Path $BuildsDir -Force | Out-Null
    Write-Ok "Pasta de saida criada: $BuildsDir"
} else {
    Write-Info "Pasta de saida pronta: $BuildsDir"
}

$ExistingContent = ""
if (Test-Path -LiteralPath $PresetsPath) {
    $ExistingContent = Get-Content -LiteralPath $PresetsPath -Raw -Encoding UTF8
    Write-Info "export_presets.cfg existente detectado; preservando presets atuais."
} else {
    Write-Info "export_presets.cfg nao existia; criando arquivo com presets Windows Desktop e Android."
}

$HasWindowsPreset = $ExistingContent -match '(?m)^platform="Windows Desktop"\s*$'
$HasAndroidPreset = $ExistingContent -match '(?m)^platform="Android"\s*$'

# Encontrar proximo indice disponivel [preset.N]
$PresetMatches = [regex]::Matches($ExistingContent, '(?m)^\[preset\.(\d+)\]\s*$')
$MaxIndex = -1
foreach ($m in $PresetMatches) {
    $idxVal = [int]$m.Groups[1].Value
    if ($idxVal -gt $MaxIndex) { $MaxIndex = $idxVal }
}
$NextIndex = $MaxIndex + 1

$NewContent = $ExistingContent.TrimEnd()

if (-not $HasWindowsPreset) {
    $winIdx = $NextIndex
    $NextIndex++
    $winOutGodot = "builds/latest/MagnataDoPampa.exe"
    $WinBlock = @"

[preset.$winIdx]

name="Windows Desktop"
platform="Windows Desktop"
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json"
exclude_filter=""
export_path="$winOutGodot"
patches=PackedStringArray()
patch_delta_encoding=false
patch_delta_compression_level_zstd=19
patch_delta_min_reduction=0.1
patch_delta_include_filters="*"
patch_delta_exclude_filters=""
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.$winIdx.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
application/company_name="RZGames"
application/product_name="Magnata do Pampa"
application/file_description="Magnata do Pampa"
"@
    if ([string]::IsNullOrWhiteSpace($NewContent)) {
        $NewContent = "[runnable_presets]`r`n`r`n`"Windows Desktop`"=`"Windows Desktop`"`r`n" + $WinBlock
    } else {
        $NewContent = $NewContent + "`r`n" + $WinBlock
    }
    Write-Ok "Preset Windows Desktop adicionado como [preset.$winIdx]."
} else {
    Write-Ok "Preset Windows Desktop ja existia e foi preservado."
}

$KeystoreOptionVal = if (Test-Path -LiteralPath $KeystorePath) { $KeystoreGodot } else { "" }

if (-not $HasAndroidPreset) {
    $andIdx = $NextIndex
    $NextIndex++

    if ($NewContent -match '(?m)^\[runnable_presets\]') {
        if ($NewContent -notmatch '(?m)^"Android"="Android"') {
            $NewContent = [regex]::Replace($NewContent, '(?m)^(\[runnable_presets\]\r?\n\r?\n)', "`$1`"Android`"=`"Android`"`r`n", 1)
        }
    }

    $AndroidBlock = @"

[preset.$andIdx]

name="Android"
platform="Android"
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json"
exclude_filter=""
export_path="$ApkOutGodot"
patches=PackedStringArray()
patch_delta_encoding=false
patch_delta_compression_level_zstd=19
patch_delta_min_reduction=0.1
patch_delta_include_filters="*"
patch_delta_exclude_filters=""
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.$andIdx.options]

custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/gradle_build_directory=""
gradle_build/android_source_template=""
gradle_build/compress_native_libraries=false
gradle_build/export_format=0
gradle_build/min_sdk=""
gradle_build/target_sdk=""
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1.0-beta"
package/unique_name="com.rzgames.magnatadopampa"
package/name="Magnata do Pampa"
package/signed=true
package/app_category=2
package/retain_data_on_uninstall=false
package/exclude_from_recents=false
package/show_in_android_tv=false
package/show_in_app_library=true
package/show_as_launcher_app=false
launcher_icons/main_192x192=""
launcher_icons/adaptive_foreground_432x432=""
launcher_icons/adaptive_background_432x432=""
launcher_icons/adaptive_monochrome_432x432=""
graphics/opengl_debug=false
xr_features/xr_mode=0
gesture/swipe_to_dismiss=false
screen/immersive_mode=true
screen/edge_to_edge=false
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
screen/background_color=Color(0.0588235, 0.0941176, 0.0745098, 1)
screen/orientation=0
user_data_backup/allow=false
command_line/extra_args=""
apk_expansion/enable=false
apk_expansion/SALT=""
apk_expansion/public_key=""
permissions/custom_permissions=PackedStringArray()
texture_format/etc2_astc=true
keystore/debug="$KeystoreOptionVal"
keystore/debug_user="androiddebugkey"
keystore/debug_password="android"
keystore/release=""
keystore/release_user=""
keystore/release_password=""
"@
    $NewContent = $NewContent.TrimEnd() + "`r`n" + $AndroidBlock
    Write-Ok "Preset Android adicionado como [preset.$andIdx] com include_filter=`"*.json`", ETC2/ASTC e saida em $ApkOutGodot."
} else {
    # Atualizar campos essenciais do preset Android existente sem mexer nos outros presets
    $androidHeader = [regex]::Match($NewContent, '(?ms)^\[preset\.(\d+)\][^\[]*?^platform="Android"\s*$')
    if ($androidHeader.Success) {
        $andIdx = $androidHeader.Groups[1].Value
        Write-Ok "Preset Android [preset.$andIdx] ja existia; garantindo include_filter, export_path, ETC2/ASTC e debug keystore."
        $NewContent = [regex]::Replace($NewContent, "(?ms)(\[preset\.$andIdx\][^\[]*?^include_filter=)`"[^`"]*`"", "`$1`"*.json`"")
        $NewContent = [regex]::Replace($NewContent, "(?ms)(\[preset\.$andIdx\][^\[]*?^export_filter=)`"[^`"]*`"", "`$1`"all_resources`"")
        $NewContent = [regex]::Replace($NewContent, "(?ms)(\[preset\.$andIdx\][^\[]*?^export_path=)`"[^`"]*`"", "`$1`"$ApkOutGodot`"")
        $NewContent = [regex]::Replace($NewContent, "(?ms)(\[preset\.$andIdx\.options\][^\[]*?^texture_format/etc2_astc=)(true|false)", "`${1}true")
        if (-not [string]::IsNullOrWhiteSpace($KeystoreOptionVal)) {
            $NewContent = [regex]::Replace($NewContent, "(?ms)(\[preset\.$andIdx\.options\][^\[]*?^keystore/debug=)`"[^`"]*`"", "`$1`"$KeystoreOptionVal`"")
        }
    }
}

[System.IO.File]::WriteAllText($PresetsPath, $NewContent.TrimEnd() + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Ok "Arquivo salvo: $PresetsPath"

# Verificar import_etc2_astc no project.godot (somente leitura)
$HasProjectEtc2 = $false
if (Test-Path -LiteralPath $ProjectGodot) {
    $pgRaw = Get-Content -LiteralPath $ProjectGodot -Raw -Encoding UTF8
    $HasProjectEtc2 = $pgRaw -match '(?m)^textures/vram_compression/import_etc2_astc=true'
    if ($HasProjectEtc2) {
        Write-Ok "project.godot ja possui textures/vram_compression/import_etc2_astc=true."
    } else {
        Write-Warn "project.godot ainda nao tem textures/vram_compression/import_etc2_astc=true (ative em Projeto -> Configuracoes do Projeto -> Rendering -> Textures -> VRAM Compression -> Import ETC2 ASTC no editor para texturas VRAM comprimidas no Android)."
    }
}

# ------------------------------------------------------------------
# 4. Localizar Godot 4.7, Export Templates e Editor Settings
# ------------------------------------------------------------------
Write-Section "4. Deteccao de Godot 4.7, Export Templates e Teste CLI"

$GodotExe = $null

# 4a. Processos em execucao
$runningGodot = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match "(?i)godot" } | Select-Object -First 1
if ($runningGodot -and $runningGodot.Path -and (Test-Path -LiteralPath $runningGodot.Path)) {
    $GodotExe = $runningGodot.Path
}

# 4b. PATH e pastas comuns
if (-not $GodotExe) {
    foreach ($cmdName in @("godot4", "godot", "godot.exe")) {
        $c = Get-Command $cmdName -ErrorAction SilentlyContinue
        if ($c -and (Test-Path -LiteralPath $c.Source)) {
            $GodotExe = $c.Source
            break
        }
    }
}

if (-not $GodotExe) {
    $GodotSearchDirs = @(
        "C:\Program Files\Godot",
        "C:\Program Files",
        "C:\Godot",
        "C:\Tools",
        (Join-Path $env:LOCALAPPDATA "Programs"),
        (Join-Path $env:USERPROFILE "Downloads"),
        (Join-Path $env:USERPROFILE "Desktop"),
        "C:\Projetos"
    )
    foreach ($sdir in $GodotSearchDirs) {
        if (-not (Test-Path -LiteralPath $sdir)) { continue }
        $found = Get-ChildItem -LiteralPath $sdir -Filter "*Godot*4.7*.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "(?i)console" } | Select-Object -First 1
        if (-not $found) {
            $found = Get-ChildItem -LiteralPath $sdir -Filter "*Godot*.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch "(?i)console" } | Select-Object -First 1
        }
        if ($found) {
            $GodotExe = $found.FullName
            break
        }
    }
}

if ($GodotExe) {
    Write-Ok "Executavel Godot encontrado: $GodotExe"
} else {
    Write-Warn "Executavel do Godot 4.7 nao localizado automaticamente."
}

# Verificar Export Templates (inclui modo self-contained ._sc_ do Godot via Steam e %APPDATA%\Godot)
$TemplateRoots = New-Object System.Collections.Generic.List[string]
if ($GodotExe) {
    $godotDir = Split-Path -Parent $GodotExe
    $scDataDir = Join-Path $godotDir "editor_data"
    if (Test-Path -LiteralPath (Join-Path $scDataDir "export_templates") -ErrorAction SilentlyContinue) {
        $TemplateRoots.Add((Join-Path $scDataDir "export_templates"))
    }
}
$AppDataTemplatesRoot = Join-Path $env:APPDATA "Godot\export_templates"
if (Test-Path -LiteralPath $AppDataTemplatesRoot -ErrorAction SilentlyContinue) {
    $TemplateRoots.Add($AppDataTemplatesRoot)
}

$AndroidTemplateDir = $null
$HasAndroidTemplates = $false

foreach ($tRoot in ($TemplateRoots | Select-Object -Unique)) {
    $tplDirs = @(Get-ChildItem -LiteralPath $tRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    if ($tplDirs.Count -gt 0) {
        Write-Info "Export Templates em ${tRoot}: $($tplDirs.Name -join ', ')"
        foreach ($td in $tplDirs) {
            if ($td.Name -match "^4\.7") {
                $dbgApk = Join-Path $td.FullName "android_debug.apk"
                $relApk = Join-Path $td.FullName "android_release.apk"
                if ((Test-Path -LiteralPath $dbgApk) -or (Test-Path -LiteralPath $relApk)) {
                    $AndroidTemplateDir = $td.FullName
                    $HasAndroidTemplates = $true
                    break
                }
            }
        }
    }
    if ($HasAndroidTemplates) { break }
}

if ($HasAndroidTemplates) {
    Write-Ok "Export Templates Android (4.7) encontrados em: $AndroidTemplateDir"
} else {
    Write-Warn "Export Templates Android 4.7 (android_debug.apk) nao encontrados."
}

# Inspecionar Editor Settings (priorizando self-contained editor_data se existir ._sc_)
$EditorSettingsCandidates = New-Object System.Collections.Generic.List[string]
if ($GodotExe) {
    $godotDir = Split-Path -Parent $GodotExe
    $scMarker = Join-Path $godotDir "._sc_"
    $scDataDir = Join-Path $godotDir "editor_data"
    if ((Test-Path -LiteralPath $scMarker -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $scDataDir -ErrorAction SilentlyContinue)) {
        $EditorSettingsCandidates.Add($scDataDir)
    }
}
$EditorSettingsCandidates.Add((Join-Path $env:APPDATA "Godot"))

$EditorSettingsFile = $null
foreach ($esDir in ($EditorSettingsCandidates | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $esDir -ErrorAction SilentlyContinue)) { continue }
    $esFound = Get-ChildItem -LiteralPath $esDir -Filter "editor_settings-4*.tres" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($esFound) {
        $EditorSettingsFile = $esFound
        break
    }
}

if ($EditorSettingsFile) {
    Write-Info "Editor Settings ativo localizado: $($EditorSettingsFile.FullName)"
    $esRaw = Get-Content -LiteralPath $EditorSettingsFile.FullName -Raw -Encoding UTF8
    $esJava = if ($esRaw -match '(?m)^export/android/java_sdk_path\s*=\s*"([^"]*)"') { $Matches[1] } else { "" }
    $esSdk  = if ($esRaw -match '(?m)^export/android/android_sdk_path\s*=\s*"([^"]*)"') { $Matches[1] } else { "" }
    $esKs   = if ($esRaw -match '(?m)^export/android/debug_keystore\s*=\s*"([^"]*)"') { $Matches[1] } else { "" }
    Write-Info "  Editor Settings -> java_sdk_path    : $(if ($esJava) { $esJava } else { '(vazio)' })"
    Write-Info "  Editor Settings -> android_sdk_path : $(if ($esSdk)  { $esSdk }  else { '(vazio)' })"
    Write-Info "  Editor Settings -> debug_keystore   : $(if ($esKs)   { $esKs }   else { '(vazio)' })"
} else {
    Write-Warn "Arquivo editor_settings-4*.tres nao encontrado."
}

# Tentar exportacao CLI se tudo estiver pronto
if ($SkipCliExport) {
    Write-Info "Exportacao CLI ignorada via -SkipCliExport."
} elseif ($GodotExe -and $HasAndroidTemplates -and $AndroidSdkPath -and $JavaHomePath -and (Test-Path -LiteralPath $KeystorePath)) {
    Write-Info "Todos os requisitos principais detectados! Testando exportacao Android Debug via CLI..."
    $env:ANDROID_HOME     = $AndroidSdkPath
    $env:ANDROID_SDK_ROOT = $AndroidSdkPath
    $env:JAVA_HOME        = $JavaHomePath

    $CliLogPath = Join-Path $BuildsDir "android_export_cli.log"
    if (Test-Path -LiteralPath $CliLogPath) { Remove-Item -LiteralPath $CliLogPath -Force -ErrorAction SilentlyContinue }

    $cliArgs = @(
        "--headless",
        "--log-file", $CliLogPath,
        "--path", $ProjectDir,
        "--export-debug", "Android", $ApkOutWin
    )

    $proc = Start-Process -FilePath $GodotExe -ArgumentList $cliArgs -NoNewWindow -Wait -PassThru
    $cliCode = $proc.ExitCode

    if (Test-Path -LiteralPath $CliLogPath) {
        $logLines = Get-Content -LiteralPath $CliLogPath -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Last 30
        foreach ($line in $logLines) {
            Write-Host "  [Godot] $line"
        }
    }

    if ($cliCode -eq 0 -and (Test-Path -LiteralPath $ApkOutWin)) {
        $apkItem = Get-Item -LiteralPath $ApkOutWin
        $sizeMb = [Math]::Round($apkItem.Length / 1MB, 2)
        Write-Ok "APK beta exportado com sucesso: $ApkOutWin ($sizeMb MB)"
    } else {
        Write-Warn "Exportacao CLI terminou com codigo $cliCode. Log salvo em: $CliLogPath"
    }
} else {
    Write-Warn "Exportacao CLI nao executada porque faltam um ou mais requisitos (GodotExe=$([bool]$GodotExe), Templates4.7=$HasAndroidTemplates, AndroidSDK=$([bool]$AndroidSdkPath), Java=$([bool]$JavaHomePath), Keystore=$(Test-Path -LiteralPath $KeystorePath))."
}

Write-Section "Resumo Final"
Write-Host "Android SDK    : $(if ($AndroidSdkPath) { $AndroidSdkPath } else { 'NAO ENCONTRADO' })"
Write-Host "Java / JBR     : $(if ($JavaHomePath)   { $JavaHomePath }   else { 'NAO ENCONTRADO' })"
Write-Host "Debug Keystore : $(if (Test-Path -LiteralPath $KeystorePath) { $KeystorePath } else { 'NAO ENCONTRADO' })"
Write-Host "Export Presets : $PresetsPath"
Write-Host "Godot 4.7 EXE  : $(if ($GodotExe)       { $GodotExe }       else { 'NAO ENCONTRADO' })"
Write-Host "Templates 4.7  : $(if ($HasAndroidTemplates) { $AndroidTemplateDir } else { 'NAO INSTALADO' })"
Write-Host "Saida APK Beta : $ApkOutWin"
