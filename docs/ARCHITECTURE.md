# Arquitetura Técnica — Magnata do Pampa (Godot 4.7.x)

## 1. Estrutura Real do Projeto (`res://`)

- **Núcleo e Regras (`core/`):**
  - `core/GameManager.gd`: orquestrador autoritativo do **Modo Clássico** (máquina de estados finita `TurnState`, economia, turnos, cartas, construções, hipotecas, negociações, falência, vitória e integração multiplayer). `main.gd` estende diretamente `res://core/GameManager.gd` na cena raiz `main.tscn`.
  - `core/BotAI.gd`: classe `RefCounted` pura (zero dependência de UI ou `SceneTree`) responsável pela tomada de decisão tática dos bots sob **5 arquétipos ocultos** (`AGRESSIVO`, `CONSERVADOR`, `MONOPOLISTA`, `IMOBILIARIO`, `ESPECULADOR`), sempre mascarados como `[BOT]` na UI, nos logs e nos snapshots de rede.
  - `core/NetworkManager.gd`: camada de rede autoritativa (Host `peer_id = 1` + até `5` clientes = 2 a 6 jogadores) com suporte a **ENet (LAN/Desktop)** e **Multiplayer Web (Relay WSS em estrela no Render + fallback WebRTC)**.
  - `core/PlatformConfig.gd`: Autoload (`PlatformConfig`) de detecção de perfil de plataforma (`desktop` vs. `android`) com suporte a `force_mobile_ui` e variável de ambiente `MAGNATA_FORCE_MOBILE` para simulação mobile no PC.
  - `core/SoundManager.gd`: síntese procedural local de efeitos sonoros (`AudioStreamWAV`) com pool de vozes e controles de mudo/volume/passos persistidos.
  - `core/BuildInfo.gd`: leitor de `res://data/version.json`, comparação SemVer/build e parser opcional de `releases/latest` no GitHub.
- **Dados Externos (`data/`):**
  - `data/board_data.json`: parâmetros econômicos base (`starting_money = 2558`, `pass_go_bonus = 200`, `bail_cost = 50`, `max_houses_bank = 32`, `max_hotels_bank = 12`) e as 40 casas do tabuleiro com campos `art_id`, `group`, `price`, `rent`, `house_cost`, `mortgage_value`.
  - `data/chance_cards.json`: baralho regional *Sorte ou Azar, Tchê!* (16 cartas).
  - `data/version.json`: metadados oficiais de versão (`version`, `build_number`, `github_repo`, `release_notes`).
- **Visual e Entidades (`entities/` e `assets/`):**
  - `entities/Board3D.gd`: implementação 3D isométrica principal com alternância fluida para câmera 2D de conferência, câmera dinâmica seguindo peão ativo, marcos 3D nos cantos, casas/hotéis 3D e dados animados.
  - `entities/BoardView.gd`: visualização 2D (`Node2D`) leve com contrato compatível para seleção de casas, posse, construções e posicionamento de peões.
  - `assets/pawns/` e `assets/tiles/`: artes temáticas regionais gaúchas.
- **Interface Híbrida (`ui/`):**
  - `ui/GameHUD.gd` e `ui/SetupScreen.gd`: camada base do HUD da partida e da tela de configuração/lobby (instanciados por `GameManager.gd`).
  - `ui/shared/`: componentes visuais comuns, paleta temática gaúcha, formatadores (`R$`) e fachada de contrato compartilhado entre Desktop e Android.
  - `ui/desktop/`: perfil dedicado Desktop (`1920x1080`, mouse/teclado, atalhos rápidos `[Espaço]`, `[C]`, `[R]`, `[E]`, `[F]`, `[L]`, `[N]`, `[Tab]`, `[ESC]`, painel lateral compacto e dock de ações desktop).
  - `ui/android/`: perfil dedicado Android (toque, alvos ampliados, espaçamento confortável para telas compactas, painel lateral proporcional ao toque e ocultação de rótulos de atalhos de teclado).
- **Ferramentas, Launcher, Sinalização e Automação (`tools/`, `.antigravity/` e `builds/`):**
  - `tools/generate_pawn_art.gd` e `tools/generate_tile_art.gd`: utilitários Godot de geração de arte.
  - `tools/launcher/`: projeto Godot 4.7 separado do Launcher Inicial (`MagnataDoPampaLauncher.exe`), isolado do projeto principal via `tools/launcher/.gdignore`.
  - `tools/signaling_server/`: servidor WebSocket Node.js (`server.mjs`) para sinalização e **Room Relay WSS** com heartbeat keepalive (ignorado pelo Godot via `.gdignore`).
  - `tools/release/`: scripts de build/exportação unificada (`build_release.ps1`, `export_builds.ps1` e `configure_android_export.ps1`, isolados via `.gdignore`).
  - `builds/`: pasta de saída local (`latest/`, `releases/`, `manifest.json`), ignorada tanto pelo Godot (`.gdignore`) quanto pelo Git (`.gitignore`).
  - `assets/brand/`: identidade visual oficial própria (`magnata_emblem.png`, `magnata_icon.ico`, `magnata_icon_192.png`, `magnata_banner.jpg`).
  - `.antigravity/rules.md`, `.antigravity/agents/*.md`, `.antigravity/automation/preflight_check.ps1`, `.antigravity/automation/export_builds.ps1` e `.antigravity/automation/validate_and_commit.ps1`: governança multiagente, validação headless, exportação e commits no Git.

---

## 2. Máquina de Estados Finita (`GameManager.TurnState`)

`core/GameManager.gd` controla todo o fluxo do Modo Clássico através do enum:

```gdscript
enum TurnState {
	WAITING_ROLL, # Aguardando jogador rolar os dados (ou pagar fiança / usar carta livre no Xadrez)
	MOVING,       # Animação de dados e deslocamento do peão entre casas (entrada bloqueada)
	EVALUATING,   # Casa disponível sem dono: jogador escolhe Comprar ou Recusar (sempre opcional)
	MANAGEMENT,   # Pós-ação do turno: construir/vender equilibrado, hipotecar/desipotecar, negociar, encerrar turno
	GAME_OVER     # Restou 1 estanceiro solvente; modal de vitória exibido
}
```

### Regras Invariantes do Fluxo de Turnos
- Comprar terreno ou companhia em `EVALUATING` é **sempre opcional** (`buy_current_property()` ou `decline_buy_property()` / `end_turn()`).
- Ações administrativas válidas (hipoteca, desipoteca `+10%`, venda equilibrada a `floori(float(house_cost) * 0.5)`, negociação, uso de carta *Sair Livre do Xadrez* ou pagamento de fiança) nunca travam o encerramento do turno.
- Duplas consecutivas concedem rolagem extra (`_has_extra_roll = true`); 3 duplas seguidas enviam ao Xadrez (`send_to_jail()`).
- Ao encerrar cada ciclo completo de jogadores ativos, `current_round` avança; a cada `3` rodadas (`TRADE_CYCLE_INTERVAL = 3`), ativa o ciclo *Feira de Negócios*.
- Falência de bot conclui transferência/devolução de bens e avança o turno automaticamente sem aguardar clique humano.

---

## 3. Contratos e Sinais Reais do Núcleo e da Apresentação

### 3.1. `core/GameManager.gd` (Núcleo Autoritativo)
**Sinais emitidos pelo núcleo para desacoplamento de UI híbrida (Desktop/Android):**
- `turn_state_changed(state: int, player_id: int, round_number: int)` — emitido a cada transição de fase/sincronização de estado do turno.
- `hud_state_synced(snapshot: Dictionary)` — payload normalizado do estado visível da partida (sem `bot_profile`) para consumo independente por adaptadores `ui/desktop/` e `ui/android/`.
- `property_purchased(player_id: int, tile_index: int, price: int)` — emitido quando uma escritura é adquirida.
- `match_event_logged(message: String)` — emitido para espelhamento de eventos públicos do Diário.
- `match_finished(victory_info: Dictionary)` — emitido ao alcançar `TurnState.GAME_OVER`.

**API pública de comandos do núcleo (acionada via sinais das UIs ou RPCs validados no Host):**
- Ciclo de partida: `load_board_data()`, `load_chance_cards()`, `open_setup_screen()`, `start_match_from_setup(player_configs: Array[Dictionary])`, `setup_match(player_configs: Array[Dictionary])`.
- Ações de turno: `roll_dice()`, `move_player(...)`, `evaluate_tile(...)`, `buy_current_property()`, `decline_buy_property()`, `pay_bail()`, `use_jail_free_card()`, `send_to_jail(player: Dictionary)`, `end_turn()`.
- Gestão patrimonial e câmera: `build_on_property(tile_idx: int)`, `sell_building_on_property(tile_idx: int)`, `toggle_mortgage(tile_idx: int)`, `execute_trade(target_id: int, offer_tile: int, request_tile: int, cash_delta: int)`, `toggle_camera_view()`, `is_market_push_round()`.

### 3.2. `core/BotAI.gd` (IA Pura — `RefCounted`)
Não emite sinais nem acessa `SceneTree`/UI. Expõe funções determinísticas/heurísticas puras:
- `assign_hidden_profiles(bot_count: int) -> Array[String]`
- Reservas por perfil: `get_buy_reserve(profile)`, `get_build_reserve(profile)`, `get_unmortgage_reserve(profile)`
- Decisões de turno: `should_use_jail_free_card(...)`, `should_pay_bail(...)`, `should_buy_property(...)`, `choose_building_to_buy(...)`, `choose_tile_to_unmortgage(...)`, `choose_liquidation_action(...)`, `should_end_turn(...)`
- Negociação dinâmica entre bots: `choose_bot_trade_proposal(...)`, `evaluate_bot_trade_offer(...)`
- Mensagens temáticas neutras (sem revelar arquétipo): `get_flavor_message(event_key, bot_name)`

### 3.3. `entities/BoardView.gd` e `entities/Board3D.gd` (Tabuleiro)
**Sinal emitido (contrato idêntico em 2D e 3D):**
- `tile_clicked(tile_index: int)` — disparado ao clicar/tocar qualquer uma das 40 casas do tabuleiro para inspeção de escritura.

**Métodos públicos principais:**
- `BoardView.gd` (2D `Node2D`): `build_board(tiles)`, `get_player_color(player_id)`, `update_ownership(owners_map, mortgaged_map)`, `update_buildings(buildings_map)`, `setup_tokens(players)`, `update_token_positions(players)`.
- `Board3D.gd` (3D isométrico + conferência 2D): implementa todo o contrato de `BoardView.gd` acrescido de `set_viewport_rect(rect)`, `toggle_camera_view()`, `is_2d_camera_active()`, `set_camera_follow_enabled(enabled)`, `is_camera_follow_enabled()`, `reset_camera_focus()`, `set_active_player(player_id)`, `animate_token_move(...)`, `play_dice_roll(d1, d2)`, `play_tile_pulse(...)`, `play_chance_card_animation(...)`, `cancel_animations()`.

### 3.4. `ui/GameHUD.gd` (HUD Base + Especializações por Plataforma)
**Sinais emitidos pela camada de HUD para o `GameManager`:**
- Ações de turno: `roll_pressed`, `buy_pressed`, `decline_buy_pressed`, `bail_pressed`, `use_jail_card_pressed`, `end_turn_pressed`
- Gestão de escrituras e trocas: `property_selected(tile_index: int)`, `build_pressed(tile_index: int)`, `sell_building_pressed(tile_index: int)`, `mortgage_pressed(tile_index: int)`, `trade_executed(target_id: int, offer_tile: int, request_tile: int, cash_delta: int)`
- Inspeção e navegação: `inspect_tile_requested(tile_index: int)`, `player_inspected(player_id: int)`, `menu_requested`, `restart_match_requested`
- Câmera e preferências: `camera_toggle_requested`, `camera_follow_toggle_requested`, `camera_reset_requested`, `board_layout_updated(board_rect: Rect2)`, `settings_updated(settings_data: Dictionary)`, `chance_card_dismissed`

### 3.5. `ui/SetupScreen.gd` e `core/NetworkManager.gd`
- `SetupScreen.gd`: emite `start_match_requested(player_configs)`, `help_requested`, `settings_requested`, `host_room_requested(port, player_name)`, `join_room_requested(address, port, player_name)`, `host_web_room_requested(signaling_url, player_name, turn_cfg)`, `join_web_room_requested(signaling_url, room_code, player_name, turn_cfg)`, `disconnect_network_requested`, `lobby_config_changed`.
- `NetworkManager.gd`: emite `network_status_changed(mode, status_text, connected_peers)`, `web_room_code_changed(room_code)`, `lobby_synced(lobby_data)`, `peer_joined_room(peer_id, peer_name)`, `peer_left_room(peer_id, peer_name)`, `connection_failed_error(message)`, `host_disconnected(reason)`, `client_action_received(sender_peer_id, session_id, action_name, params)`, `remote_match_started(session_id, snapshot)`, `remote_state_received(session_id, snapshot)`, `remote_event_received(session_id, event_type, payload)`.

---

## 4. Separação Híbrida de UI (`ui/shared/`, `ui/desktop/`, `ui/android/`)

A escolha de perfil de interface é controlada exclusivamente pelo Autoload `PlatformConfig.is_mobile_ui_active()` (incluindo `force_mobile_ui` e `MAGNATA_FORCE_MOBILE=1` para testes mobile no PC):

| Camada | Caminho | Responsabilidade |
|---|---|---|
| **Compartilhado** | `res://ui/shared/UIStyleTokens.gd` | Paleta gaúcha moderna, criação padronizada de `StyleBoxFlat`, formatação monetária BRL (`R$`) e constantes de layout. |
| **Compartilhado** | `res://ui/shared/PlatformProfileAdapter.gd` | Contrato tipado de perfil de plataforma (fator de fonte, altura mínima de botões, margens de viewport, visibilidade de atalhos de teclado e metadados de HUD) + factory `create_for_active_platform()`. |
| **Desktop** | `res://ui/desktop/DesktopGameHUD.gd` | Especialização de `GameHUD` para Desktop (`1920x1080`): mouse/teclado, dicas de atalhos `[Espaço]/[C]/[R]/[E]/[F]/[L]/[N]/[Tab]`, painel lateral equilibrado (`24.5%`, `430..520px`), `board_layout_updated` otimizado para tela ampla. |
| **Desktop** | `res://ui/desktop/DesktopSetupScreen.gd` | Especialização de `SetupScreen` para Desktop: grade de 2 colunas de estanceiros, barra de modo Local / P2P LAN ENet / WebRTC e atalhos de início rápido. |
| **Android** | `res://ui/android/AndroidGameHUD.gd` | Especialização de `GameHUD` para Android/Toque: áreas de toque generosas (`1.28x`), tipografia ampliada (`1.22x`), rótulos limpos sem sufixos de teclado, painel lateral dimensionado para leitura confortável em celulares e modais amplos com rolagem tátil. |
| **Android** | `res://ui/android/AndroidSetupScreen.gd` | Especialização de `SetupScreen` para Android/Toque: botões e controles ampliados para toque, espaçamento confortável e adaptação automática de colunas para telas compactas. |

### Regra de Ouro de Desacoplamento
- `GameManager.gd` instancia o par de telas via `PlatformConfig.is_mobile_ui_active()`:
  - `true` → `AndroidGameHUD` (`res://ui/android/AndroidGameHUD.gd`) + `AndroidSetupScreen` (`res://ui/android/AndroidSetupScreen.gd`).
  - `false` → `DesktopGameHUD` (`res://ui/desktop/DesktopGameHUD.gd`) + `DesktopSetupScreen` (`res://ui/desktop/DesktopSetupScreen.gd`).
- Nenhuma regra econômica, de turnos, construção, hipoteca, falência ou IA é duplicada em `ui/desktop/`, `ui/android/` ou `ui/shared/`.

---

## 5. Parâmetros do Modo Clássico e Diretrizes de Qualidade

- **Jogadores:** 2 a 6 (bots identificados apenas como `[BOT]`).
- **Economia base:** saldo inicial `R$ 2.558`, terrenos a partir de `R$ 60`, `32` casas e `12` hotéis no banco, monopólio dobrando aluguel de terreno sem construções, companhias por `dice_sum * multiplier`, desipoteca com `+10%`, venda equilibrada de construções a `floori(float(house_cost) * 0.5)` e falência preservando regras oficiais.
- **Qualidade:** GDScript 2.0 estritamente tipado, `0` avisos de `INTEGER_DIVISION`, execução de apenas 1 instância do Godot por vez (Ryzen 7 5700G / 16GB RAM) e validação via `.antigravity/automation/validate_and_commit.ps1`.

---

## 6. Árvore Oficial do Repositório Unificado e Comandos

```text
magnata-do-pampa/
├── project.godot, export_presets.cfg, main.gd, main.tscn, .gitignore
├── core/                  # Regras do Modo Clássico, BotAI, NetworkManager, PlatformConfig, SoundManager, BuildInfo
├── data/                  # board_data.json, chance_cards.json, version.json
├── entities/              # Board3D.gd, BoardView.gd
├── ui/                    # GameHUD, SetupScreen e especializações shared/ desktop/ android/
├── assets/                # Artes dos peões e casas
├── addons/                # Plugins do editor
├── docs/                  # ARCHITECTURE.md, GDD.md, BACKLOG.json
├── .antigravity/          # Regras, perfis de agentes e automação (preflight, export_builds, validate_and_commit)
├── tools/
│   ├── generate_pawn_art.gd, generate_tile_art.gd
│   ├── launcher/          # (.gdignore) Projeto Godot do Launcher Inicial (.exe)
│   ├── signaling_server/  # (.gdignore) Servidor Node.js WebSocket WebRTC (server.mjs)
│   └── release/           # (.gdignore) Atalhos build_release.ps1 e configure_android_export.ps1
└── builds/                # (.gdignore + .gitignore) Artefatos gerados (.exe, .apk, .zip, manifest.json)
```

- **Preflight e Validação + Commit:**
  - `powershell -ExecutionPolicy Bypass -File .\.antigravity\automation\preflight_check.ps1`
  - `powershell -ExecutionPolicy Bypass -File .\.antigravity\automation\validate_and_commit.ps1 -CommitMessage "mensagem"`
- **Exportação Automatizada (Windows + Android + Launcher):**
  - `powershell -ExecutionPolicy Bypass -File .\tools\release\build_release.ps1 -Targets All`
  - Flags úteis: `-BumpPatch`, `-BumpMinor`, `-NoBump`, `-GitHubRepo "usuario/repo"`, `-SkipGitHubRelease`.
- **Sinalização WebRTC local:**
  - `node .\tools\signaling_server\server.mjs`
- **Launcher em desenvolvimento / produção:**
  - Código-fonte em `tools/launcher/` e executável exportado em `builds/latest/MagnataDoPampaLauncher.exe`.
