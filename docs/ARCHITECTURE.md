# Arquitetura Técnica — Magnata do Pampa (Godot 4.7.x)

## 1. Estrutura Real do Projeto (`res://`)
- **Núcleo e Regras (`core/`):**
  - `core/GameManager.gd`: máquina de estados finita de turnos (`TurnState`), economia do Modo Clássico e regras centrais.
  - `core/BotAI.gd`: tomada de decisão dos bots (mantendo sigilo de arquétipo/perfil como `[BOT]`).
  - `core/NetworkManager.gd`: comunicação multiplayer/rede.
  - `core/PlatformConfig.gd`: Autoload de detecção de plataforma (`Android` vs. `Desktop`) com suporte a `force_mobile_ui` e variável de ambiente `MAGNATA_FORCE_MOBILE` para simular o layout mobile no PC.
- **Dados (`data/`):**
  - `data/board_data.json` e `data/chance_cards.json`: dados externos estruturados de casas, propriedades, valores e cartas.
- **Visual e Entidades (`entities/` e `assets/`):**
  - `entities/Board3D.gd` e `entities/BoardView.gd`: renderização 3D isométrica, câmera de conferência/tabuleiro e peões/casas.
  - `assets/pawns/` e `assets/tiles/`: artes temáticas regionais gaúchas.
- **Interface (`ui/`):**
  - `ui/GameHUD.gd` e `ui/SetupScreen.gd`: telas atuais do jogo, a serem evoluídas para interfaces dedicadas em `ui/desktop/` e `ui/android/` com componentes compartilhados em `ui/shared/` sem duplicar regras de jogo.
- **Ferramentas e Automação (`tools/` e `.antigravity/`):**
  - `tools/generate_pawn_art.gd` e `tools/generate_tile_art.gd`: geração/apoio de arte.
  - `.antigravity/rules.md`, `.antigravity/agents/*.md` e `.antigravity/automation/validate_and_commit.ps1`: governança multiagente, validação headless e commits no Git.

## 2. Parâmetros do Modo Clássico e Diretrizes
- **Jogadores:** 2 a 6 (bots identificados apenas como `[BOT]`).
- **Economia base:** saldo inicial de `R$ 2.558`, terrenos a partir de `R$ 60`, `32` casas e `12` hotéis no banco, deshipoteca com `+10%`, venda de construções com `floori(float(house_cost) * 0.5)` e falência repassando propriedades (preservando hipotecas e devolvendo construções ao banco) ou devolvendo ao banco em dívida pública.
- **Estética e Câmera:** visual moderno com temática regional gaúcha, visão 3D isométrica com alternância para câmera 2D de conferência e perfis dedicados para Desktop e Android.
- **Qualidade:** GDScript 2.0 estritamente tipado, sem `INTEGER_DIVISION` e com edição autônoma de cenas `.tscn` validada via `godot --headless`.