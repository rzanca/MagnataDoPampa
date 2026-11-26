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