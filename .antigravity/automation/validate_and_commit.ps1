param(
    [string]$CommitMessage = "chore(auto): atualizacao validada pelo pipeline"
)

$GodotExe = Get-ChildItem "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\" -Filter "*godot*.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike "*console*" } |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $GodotExe) {
    Write-Error "Executavel do Godot nao encontrado na pasta da Steam."
    exit 1
}

Write-Host "1/3 Atualizando cache e UIDs do projeto..." -ForegroundColor Cyan
& $GodotExe --headless --import --quit *> $null

Write-Host "2/3 Validando sintaxe e executando Smoke Test (120 frames)..." -ForegroundColor Cyan
$Output = & $GodotExe --headless --quit-after 120 2>&1 | Out-String

# Filtra apenas erros reais nos scripts do jogo (ignorando o plugin addons/gamedev_ai em modo headless)
$GameErrors = ($Output -split "`r?`n") | Where-Object {
    ($_ -match "SCRIPT ERROR:|Parse Error:|ERROR:") -and
    ($_ -notmatch "addons/gamedev_ai") -and
    ($_ -notmatch "ObjectDB instances were leaked") -and
    ($_ -notmatch "resources still in use at exit")
}

if ($GameErrors) {
    Write-Host "Erros encontrados nos arquivos do jogo:" -ForegroundColor Red
    $GameErrors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    exit 1
}

Write-Host "3/3 Validacao OK! Salvando ponto de restauracao no Git..." -ForegroundColor Green
git add .
git commit -m $CommitMessage