# Game Design Document (GDD) — Magnata do Pampa

## 1. Visão do Produto
- **Título:** Magnata do Pampa
- **Gênero:** Jogo de tabuleiro digital estratégico (Modo Clássico).
- **Ambientação e Estética:** Temática regional gaúcha com visual moderno e limpo (sem pixel art/retrô), usando `StyleBoxFlat`, tipografia clara, visão híbrida 3D isométrica e câmera 2D de conferência.
- **Plataformas Alvo:** Desktop e Android, com interfaces dedicadas (`ui/desktop/` e `ui/android/`), componentes comuns em `ui/shared/` e regras/estado isolados em `core/` e `data/`.

## 2. Loop Principal e Regras do Modo Clássico
- **Jogadores:** 2 a 6 participantes (humanos locais, bots com identidade oculta exibida como `[BOT]` e suporte multiplayer/P2P/online).
- **Economia Base:**
  - Saldo inicial: `R$ 2.558`.
  - Terrenos: a partir de `R$ 60`.
  - Limites do banco: `32` casas e `12` hotéis.
  - Monopólio: aluguel dobrado quando o dono possui todo o grupo de cor sem construções.
  - Companhias: `dice_sum * multiplier`.
  - Hipoteca / Deshipoteca: deshipoteca com acréscimo de `+10%`.
  - Construção e Venda: equilíbrio por grupo de cor; venda de construções retorna metade do custo (`floori(float(house_cost) * 0.5)`).
  - Falência: liquidação prévia de ativos/construções quando possível; na falência real contra jogador, construções voltam ao banco e escrituras (com estado de hipoteca) vão ao credor; em dívida pública, propriedades livres voltam ao banco.

## 3. Critérios de Avaliação Crítica de Novas Ideias
- **Clareza de leitura:** A novidade facilita ou atrapalha entender quem é o dono, quanto custa o aluguel ou de quem é a vez?
- **Ergonomia por plataforma:** Funciona bem no mouse/teclado do Desktop e no toque do Android sem esconder o tabuleiro?
- **Impacto na economia e no ritmo:** Evita travas de turno, loops infinitos de troca/leilão ou inflação/quebra do saldo inicial de `R$ 2.558`?

## 4. Fluxos Refinados (Modo Clássico)
- **Gestão Centralizada na Carta do Lote:** O painel lateral exibe apenas `Estanceiros` e `Diário`, eliminando a aba separada de escrituras. Todas as ações individuais (`+Casa`, `-Casa`, `Hipotecar/Desipotecar`, `Ofertar em Troca`, `Propor Troca por Este Lote` e `Carrinho de Obras`) ficam reunidas na **Carta do Lote**, com acesso rápido pela carteira (`Minhas Escrituras` / `Quitar Dívida`) ou tocando qualquer casa no tabuleiro 3D/2D.
- **Evento Feriadão de 20 de Setembro (Casa 20 — Opção A):**
  - Ao parar na casa `20` (`FREE_PARKING`), dispara celebração temática sem criar bolão inflacionário:
    1. Havendo terrenos/companhias livres no Banco e `>= 2` jogadores solventes para o lance mínimo: convoca imediatamente um **Leilão Farroupilha (Acampamento de Remates)** de um lote livre.
    2. Sem lotes livres ou sem quórum para leilão: realiza o **Rateio de Chimarrão no Galpão** (`R$ 20` simbólicos de cada adversário ativo com saldo suficiente — soma zero) ou pró-labore único de `R$ 50` da Semana Farroupilha caso nenhum adversário possua saldo.
- **Liquidação Inteligente, Hipotecas e Falência Automática:** A Carteira (`Minhas Escrituras` / `Quitar Dívida`) oferece filtro rápido (`Todas | Hipotecáveis | Hipotecadas`) e ações de 1 clique (`Hipotecar`, `Desipotecar +10%`, `-Casa 50%`); se a soma máxima liquidável for insuficiente para cobrir a dívida (`saldo + patrimonio_liquidavel < 0`), a falência automática é decretada sem travar em cliques inúteis.
- **Leilão de Escritura Própria:** Pela Carta do Lote, o dono pode colocar escritura livre de construções e sem hipoteca em leilão entre adversários (máximo 1 por turno), recebendo o valor arrematado.
- **Desistência / Passar Vaga para `[BOT]`:** Humano local (com `>= 2` participantes ativos) ou cliente online pode passar sua vaga para `[BOT]` sem encerrar a mesa dos demais.
- **Áudio Procedural & Controles:** `SoundManager` procedural via `AudioStreamWAV` com opções de Mudo, Volume e Sons de Passos/UI persistidas em `preferences.cfg`.
## 5. Evolução de Identidade Própria (PILA, Estações, Áudio, Câmera/UX & 3D)
- **Moeda Oficial:** **PILA** (`P$ 2.558` em cards/tabuleiro/HUD e `"2.558 Pilas"` em textos e logs narrativos).
- **Modos de Partida e Estações do Pampa:**
  - **Estância Dinâmica (padrão anti-tédio):** inicia com draft de `2` escrituras aleatórias por estanceiro, **Estações do Pampa** rotacionando a cada `3` rodadas (*Primavera*, *Verão*, *Outono*, *Inverno* com modificadores econômicos reais) e condições ágeis de encerramento (`30` rodadas por maior patrimônio líquido, `3` monopólios ou `12.000 Pilas` líquidos).
  - **Clássico Tradicional:** mantém todas as regras tradicionais puras (`0` cartas iniciais, sem limite de rodadas).
- **Baralho Sazonal (*Sorte ou Azar, Tchê!*):** `24` cartas incluindo eventos e problemas climáticos sazonais (geada negra, estiagem, enchente de arroio, gafanhotos, safra recorde, vindima, leilão de terneiros e festival de inverno).
- **Áudio Temático Gaúcho (`SoundManager`):** síntese procedural multi-harmônica inspirada em acordeon/fandango, violão pampeano dedilhado, trote de casco, dados na madeira, tilintar de Pilas e martelo de remate.
- **Exploração & UX Livre:** câmera com pan/arraste e zoom suave (`scroll` / pinça / atalhos), foco dinâmico bem próximo ao peão durante a caminhada, e todos os popups/modais do HUD arrastáveis pela barra de título.
- **Identidade 3D & Artes de Marca:** centro do tabuleiro com brasão oficial, `40` artes de lotes renovadas sob o novo branding, fundo exclusivo para as cartas de Sorte ou Azar e modelos `.glb` gerados via Blender headless (6 peões, construções campeiras, dados chanfrados e enfeites temáticos nos lotes).