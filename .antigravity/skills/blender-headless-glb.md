# Skill: Geração Headless de Assets 3D (.glb) com Blender + Python

Use esta skill ao gerar ou atualizar modelos 3D modulares (peças de tabuleiro, marcos, construções, adereços) via Blender em modo background.

## Diretrizes
1. **Execução sem interface gráfica:** Rode sempre via CLI (`blender --background --python <script.py>`) e **uma única instância por vez** para respeitar os 16GB de RAM com vídeo integrado do Ryzen 7 5700G.
2. **Base e escala consistentes:** Posicione o pivô/base na altura de referência (`Z = 0` no chão do modelo) e aplique transformações (`scale` / `rotation`) antes de exportar.
3. **Exportação limpa:** Exporte em `glTF 2.0 (.glb)` dentro da pasta de assets do projeto para importação direta no Godot 4.7.2.
4. **Sem loops infinitos:** Scripts `.py` devem encerrar automaticamente após exportar o `.glb`.