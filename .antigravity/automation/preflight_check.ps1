$ErrorActionPreference = "Stop"
Write-Host "=== Conferencia Automatica: Magnata do Pampa ===" -ForegroundColor Cyan

if (-not (Test-Path ".\project.godot")) { Write-Error "Rode dentro de magnata-do-pampa!"; exit 1 }

# Verifica sincronia entre GEMINI.md raiz e .antigravity/rules.md
if (Test-Path "..\GEMINI.md") {
    $hashRoot = (Get-FileHash "..\GEMINI.md").Hash
    $hashSub  = (Get-FileHash ".\.antigravity\rules.md").Hash
    if ($hashRoot -ne $hashSub) {
        Copy-Item ".\.antigravity\rules.md" "..\GEMINI.md" -Force
        Write-Host "[AUTO-FIX] ..\GEMINI.md sincronizado com .antigravity\rules.md" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Regras sincronizadas (GEMINI.md == rules.md)" -ForegroundColor Green
    }
}

# Verifica Autoloads no project.godot
$autoloads = Select-String -Path ".\project.godot" -Pattern '^[A-Za-z0-9_]+="\*?res://(.+?)"'
foreach ($m in $autoloads) {
    $rel = $m.Matches[0].Groups[1].Value -replace '/', '\'
    if (Test-Path $rel) {
        Write-Host "[OK] Autoload verificado: res://$($m.Matches[0].Groups[1].Value)" -ForegroundColor Green
    } else {
        Write-Host "[ERRO] Autoload ausente: res://$($m.Matches[0].Groups[1].Value)" -ForegroundColor Red
        exit 1
    }
}

# Verifica Git e processos
$godotProcs = Get-Process | Where-Object { $_.ProcessName -match "godot" }
if ($godotProcs) {
    Write-Host "[AVISO] Godot aberto em segundo plano ($($godotProcs.Count) processo(s))." -ForegroundColor Yellow
} else {
    Write-Host "[OK] Nenhum processo concorrente do Godot (RAM livre no 5700G)." -ForegroundColor Green
}

Write-Host "[OK] Repositorio Git branch: $(git branch --show-current)" -ForegroundColor Green
