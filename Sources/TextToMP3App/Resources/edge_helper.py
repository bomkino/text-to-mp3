#!/usr/bin/env python3
"""Small private bridge between native Mac UI and edge-tts."""

import argparse
import asyncio
import json
from pathlib import Path

import edge_tts


async def retry(operation, attempts: int = 3):
    for attempt in range(attempts):
        try:
            return await operation()
        except Exception:
            if attempt == attempts - 1:
                raise
            await asyncio.sleep(0.75 * (2**attempt))


async def list_voices() -> None:
    voices = await retry(edge_tts.list_voices)
    payload = [
        {
            "shortName": voice["ShortName"],
            "locale": voice["Locale"],
            "gender": voice["Gender"],
            "friendlyName": voice.get("FriendlyName", voice["ShortName"]),
        }
        for voice in voices
    ]
    print(json.dumps(payload, ensure_ascii=False))


async def synthesize(args: argparse.Namespace) -> None:
    text = Path(args.text_file).read_text(encoding="utf-8")
    if not text.strip():
        raise ValueError("Text is empty.")

    async def save() -> None:
        communicate = edge_tts.Communicate(
            text,
            args.voice,
            rate=args.rate,
            volume="+0%",
            pitch="+0Hz",
        )
        await communicate.save(args.output)

    await retry(save)


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser()
    commands = root.add_subparsers(dest="command", required=True)
    commands.add_parser("voices")

    render = commands.add_parser("synthesize")
    render.add_argument("--text-file", required=True)
    render.add_argument("--output", required=True)
    render.add_argument("--voice", required=True)
    render.add_argument("--rate", default="+0%")
    return root


async def main() -> None:
    args = parser().parse_args()
    if args.command == "voices":
        await list_voices()
    else:
        await synthesize(args)


if __name__ == "__main__":
    asyncio.run(main())
