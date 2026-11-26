param(
    [Parameter(Mandatory = $true)]
    [string]$Idea
)

if (-not (Test-Path ".\project.godot")) {
    Write-Error "Rode este script dentro de magnata-do-pampa."
    exit 1
}

powershell -ExecutionPolicy Bypass -File .\.antigravity\automation\preflight_check.ps1

$Prompt = @"
Atue como o agente em .antigravity/agents/00_product_manager.md respeitando .antigravity/rules.md, docs/GDD.md, docs/ARCHITECTURE.md e docs/BACKLOG.json.
Avalie de forma criativa e critica esta ideia para o Modo Classico do Magnata do Pampa:
"$Idea"
Aponte pontos fortes, riscos economicos/de UI/Android e atualize docs/GDD.md ou docs/BACKLOG.json apenas se fizer sentido. Ao final, se houver alteracao de arquivos, rode .\.antigravity\automation\validate_and_commit.ps1.
"@

$Prompt | Set-Clipboard
Write-Host "[OK] Prompt do Product Manager copiado para a area de transferencia. Cole no Antigravity com Ctrl+V!" -ForegroundColor Green