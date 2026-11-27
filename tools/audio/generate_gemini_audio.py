#!/usr/bin/env python3
"""Gera trilhas sazonais pampeanas via Google Gemini API (Lyria 3.5) para Magnata do Pampa.

Uso:
    pip install -U google-genai
    set GEMINI_API_KEY=sua_chave_aqui
    python tools/audio/generate_gemini_audio.py
"""

import base64
import os
import sys
from pathlib import Path


SEASON_PROMPTS = {
    "primavera": (
        "Instrumental Brazilian gaucho acoustic guitar and soft accordion milonga, "
        "warm spring morning in southern Brazil pampa, gentle 76 BPM, uplifting yet relaxed background loop."
    ),
    "verao": (
        "Instrumental Brazilian gaucho chamame with acoustic guitar and subtle concertina, "
        "bright warm summer afternoon on a ranch, steady acoustic groove, no vocals."
    ),
    "outono": (
        "Instrumental nostalgic southern Brazilian milonga on nylon acoustic guitar and soft accordion, "
        "crisp autumn dusk in Rio Grande do Sul, calm reflective background music."
    ),
    "inverno": (
        "Calm fireside instrumental acoustic guitar and warm sustained accordion chords, "
        "winter frost night in a gaucho ranch galpao, slow peaceful ambient background."
    ),
}


def main() -> int:
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("ERRO: Defina a variavel de ambiente GEMINI_API_KEY antes de executar.", file=sys.stderr)
        return 1

    try:
        from google import genai
    except ImportError:
        print("ERRO: Pacote 'google-genai' nao encontrado. Execute: pip install -U google-genai", file=sys.stderr)
        return 1

    repo_root = Path(__file__).resolve().parents[2]
    out_dir = repo_root / "assets" / "audio" / "ambient"
    out_dir.mkdir(parents=True, exist_ok=True)

    client = genai.Client(api_key=api_key)
    for season_id, prompt in SEASON_PROMPTS.items():
        out_path = out_dir / f"{season_id}.mp3"
        print(f"Gerando trilha sazonal '{season_id}' em {out_path}...")
        interaction = client.interactions.create(
            model="lyria-3-clip-preview",
            input=prompt,
        )
        audio = getattr(interaction, "output_audio", None)
        if not audio or not getattr(audio, "data", None):
            print(f"AVISO: Sem bloco de audio retornado para {season_id}.", file=sys.stderr)
            continue
        out_path.write_bytes(base64.b64decode(audio.data))
        print(f"[OK] Salvo: {out_path}")

    print("Concluido! SoundManager.gd carregara as faixas automaticamente.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
