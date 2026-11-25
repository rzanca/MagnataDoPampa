param(
    [string]$CommitMessage = "chore(auto): atualizacao validada pelo pipeline"
)

# Localiza o executável do Godot instalado via Steam
$GodotPaths = @(
    "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
    "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\Godot_v4.7-stable_win64.exe"
)

$GodotExe = $GodotPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $GodotExe) {
    # Busca dinâmica caso o nome do exe da Steam varie
    $Found = Get-ChildItem "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\" -Filter "*godot*.exe" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1
    if ($Found) { $GodotExe = $Found.FullName }
}

if (-not $GodotExe) {
    Write-Error "Executável do Godot não encontrado na pasta padrão da Steam. Ajuste o caminho no script."
    exit 1
}

Write-Host "1/3 Reimportando assets e validando projeto no Godot Headless..." -ForegroundColor Cyan
& $GodotExe --headless --import --quit
if ($LASTEXITCODE -ne 0) { Write-Error "Falha na reimportação!"; exit 1 }

Write-Host "2/3 Executando Smoke Test de 120 frames..." -ForegroundColor Cyan
& $GodotExe --headless --quit-after 120
if ($LASTEXITCODE -ne 0) { Write-Error "Erro de runtime detectado no Smoke Test!"; exit 1 }

Write-Host "3/3 Validação OK! Salvando ponto de restauração no Git..." -ForegroundColor Green
git add .
git commit -m $CommitMessage