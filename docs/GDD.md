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