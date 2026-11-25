# Regras Permanentes do Projeto — Magnata do Pampa

## 1. Engine, Linguagem e Hardware
- **Engine:** Godot 4.7.x padrão.
- **Linguagem:** 100% GDScript com **tipagem estática obrigatória** em todas as variáveis, parâmetros, loops e retornos de funções (ex.: `var x: int`, `func foo() -> void`).
- **Qualidade de Código:** Zero avisos de divisão inteira (`INTEGER_DIVISION`) e zero uso de sintaxe ou APIs legadas do Godot 3. Utilize exclusivamente padrões e APIs modernos do Godot 4.x (`maxi`, `mini`, `absi`, `roundi`, `floori`, `clampi`, etc.).
- **Hardware e Execução:** Máquina com Windows, AMD Ryzen 7 5700G e 16GB de RAM (sem LLM local; inteligência via AI Pro e automação determinística local). Executar apenas uma instância pesada (Godot ou Blender) por vez, nunca em paralelo.

## 2. Escopo, Estética e Diretrizes de Domínio
- **Título:** *Magnata do Pampa*.
- **Direção Visual:** Estética **moderna com temática regional gaúcha** (sem estilo retrô/pixel art): tipografia limpa, superfícies modernas com `StyleBoxFlat`, hierarquia visual refinada e preparação arquitetural para **visão híbrida 3D Isométrica com alternância para câmera 2D de conferência**.
- **Foco Atual:** **Exclusivo no Modo Clássico** (baseado na edição recente do Banco Imobiliário Luxo) até toda a gameplay e a apresentação estética estarem lapidadas. Modos especiais ficam adiados.
- **Modos de Jogadores:** Suporte de **2 a 6 jogadores** (single-player contra bots com arquétipos ocultos e multiplayer local/futuro online).
- **Regras Econômicas Base (Modo Clássico):**
  - **Saldo inicial:** `R$ 2.558`.
  - **Terrenos:** preços a partir de `R$ 60`.
  - **Limites do banco:** `32` casas e `12` hotéis.
  - **Monopólio:** aluguel dobrado em terrenos do mesmo grupo de cor quando o proprietário possui todo o conjunto e não há construções.
  - **Companhias:** aluguel calculado pela **soma dos dados** multiplicada pelo fator da companhia (`dice_sum * multiplier`).
  - **Hipoteca e Desipoteca:** desipoteca com acréscimo de **+10%** sobre o valor hipotecado.
  - **Construção e Venda Equilibradas:** construir e vender respeitam equilíbrio por grupo de cor; venda credita metade do custo (`floori(float(house_cost) * 0.5)`).
  - **Falência:** transfere propriedades ao credor (se vivo) preservando hipotecas e devolvendo construções ao banco, ou devolve livres ao banco quando a dívida é pública.

## 3. Arquitetura e Separação por Plataforma
- **Separação Estrita de Responsabilidades:** Manter separação clara entre **lógica de regras/estado** (`GameManager` / máquina de estados finita de turnos), **IA de bots** (`BotAI`) e **interface/visual** (`BoardView`, `GameHUD`, `SetupScreen`). A lógica nunca deve acessar controles internos privados da UI, e a IA nunca deve depender de UI ou `SceneTree`.
- **Plataformas (Desktop + Android):** Núcleo compartilhado em `core/` e `data/`; interfaces e ajustes específicos isolados para Desktop e Android sem duplicar regras de negócio.
- **Sigilo dos Bots:** Os perfis internos dos bots são ocultos para o jogador humano tanto no HUD quanto nos logs (exibir apenas `[BOT]`).
- **Orientação a Dados:** Utilize dados externos estruturados (`Resource`/`.tres` ou JSON de configuração com campos preparados para arte como `art_id`) para definir propriedades, casas do tabuleiro, cartas e parâmetros econômicos.
- **Controle de Turnos:** Utilize uma **Máquina de Estados Finita** (`TurnState`) para gerenciar o fluxo de turnos, garantindo que comprar seja sempre opcional e que ações válidas (hipotecar/desipotecar, vender construções, trocar, usar carta de sair livre ou estar no Xadrez) nunca travem o encerramento do turno.
- **Instanciação Orientada a Dados:** **Nunca** crie dezenas de nós manuais repetitivos na cena quando for possível instanciá-los dinamicamente a partir dos dados.

## 4. Cenas e Automação
- Os agentes podem criar, editar e montar cenas `.tscn` e scripts `.gd` diretamente sem pedir confirmação prévia, desde que validem via linha de comando (`godot --headless`) e registrem commits no Git quando os testes passarem.
- Nunca deixar funções vazias, `pass` de placeholder ou código incompleto.