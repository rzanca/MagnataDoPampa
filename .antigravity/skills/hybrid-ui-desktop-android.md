# Skill: UI Híbrida Dedicada (Desktop vs. Android) no Godot 4.7.x

Use esta skill ao criar, refatorar ou ajustar telas, HUDs, câmeras ou controles de entrada para Desktop e Android.

## Diretrizes
1. **Núcleo intacto:** Nenhuma regra do Modo Clássico (economia, turnos, compra, leilão, hipoteca, falência ou sigilo `[BOT]`) pode ficar dentro de scripts de UI.
2. **Detecção centralizada:** Consulte `PlatformConfig.is_mobile_ui_active()` (que já considera `OS.get_name() == "Android"`, `force_mobile_ui` e `MAGNATA_FORCE_MOBILE`).
3. **Desktop (`ui/desktop/`):** Prioriza visão ampla do tabuleiro isométrico/2D de conferência, atalhos de teclado e painéis de inspeção sem poluir o centro da tela.
4. **Android (`ui/android/`):** Prioriza botões de toque amplos na base/zona do polegar, fontes legíveis em tela menor, painéis retráteis para não cobrir o tabuleiro e cuidado com proporção/margens.
5. **Componentes comuns (`ui/shared/`):** Reutilize cartões, modais e notificações quando o comportamento visual for o mesmo, variando apenas escala/layout.
6. **Tipagem estática:** Use tipos explícitos em GDScript 2.0 e evite `INTEGER_DIVISION`.