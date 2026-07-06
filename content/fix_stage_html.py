#!/usr/bin/env python3
"""Fix Stage landing HTML: remove CMS-duplicate header/tabs, keep full content."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def extract_from_transcript(transcript_path: Path) -> str:
    with transcript_path.open(encoding="utf-8") as f:
        for line in f:
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("role") != "user":
                continue
            for part in obj.get("message", {}).get("content", []):
                if part.get("type") != "text":
                    continue
                text = part.get("text", "")
                marker = '<div class="tpk-stage-blue-theme">'
                alt = 'class="tpk-stage-blue-theme"'
                if alt not in text:
                    continue
                start = text.find(marker)
                if start == -1:
                    # bis_size variant
                    m = re.search(
                        r'<div[^>]*class="tpk-stage-blue-theme"[^>]*>',
                        text,
                    )
                    if not m:
                        continue
                    start = m.start()
                chunk = text[start:]
                # Stop at whatsapp float end (last meaningful close)
                wa = chunk.rfind('class="tpk-whatsapp-float"')
                if wa != -1:
                    close = chunk.find("</div>", wa)
                    if close != -1:
                        chunk = chunk[: close + len("</div>")]
                return chunk
    raise RuntimeError("Original HTML not found in transcript")


def remove_block(html: str, class_name: str) -> str:
    """Remove first div with exact class token (handles nested divs)."""
    pattern = re.compile(
        rf'<div[^>]*\bclass="[^"]*\b{re.escape(class_name)}\b[^"]*"[^>]*>',
        re.IGNORECASE,
    )
    m = pattern.search(html)
    if not m:
        return html
    start = m.start()
    i = m.end()
    depth = 1
    while i < len(html) and depth:
        open_m = re.search(r"<div\b", html[i:], re.IGNORECASE)
        close_m = re.search(r"</div>", html[i:], re.IGNORECASE)
        if not close_m:
            break
        if open_m and open_m.start() < close_m.start():
            depth += 1
            i += open_m.end()
        else:
            depth -= 1
            i += close_m.end()
    return html[:start] + html[i:]


def strip_bis_size(html: str) -> str:
    return re.sub(r'\s*bis_size="[^"]*"', "", html)


def fix_html(html: str) -> str:
    html = remove_block(html, "tpk-top-card")
    html = remove_block(html, "tpk-tabs")
    html = strip_bis_size(html)
    # Normalize broken image/video URLs (trailing spaces)
    html = re.sub(
        r'(src="[^"]+?)\s+"',
        r'\1"',
        html,
    )
    html = re.sub(
        r'(href="[^"]+?)\s+"',
        r'\1"',
        html,
    )
    return html


def main() -> int:
    base = Path(__file__).resolve().parent
    transcript = Path(
        r"C:\Users\prana\.cursor\projects\e-New-TPK-2026-Apps-neetprep-admin-web"
        r"\agent-transcripts\49ff0fa4-f46d-46a7-bc20-843caff51db3"
        r"\49ff0fa4-f46d-46a7-bc20-843caff51db3.jsonl"
    )
    input_path = base / "stage-1-planning-neet-usa-original.html"
    output_path = base / "stage-1-planning-neet-usa-fixed.html"

    if len(sys.argv) > 1:
        input_path = Path(sys.argv[1])
    if len(sys.argv) > 2:
        output_path = Path(sys.argv[2])

    if input_path.exists():
        html = input_path.read_text(encoding="utf-8")
    elif transcript.exists():
        html = extract_from_transcript(transcript)
        input_path.write_text(html, encoding="utf-8")
        print(f"Extracted original -> {input_path}")
    else:
        print("No input HTML found.", file=sys.stderr)
        return 1

    fixed = fix_html(html)
    output_path.write_text(fixed, encoding="utf-8")
    print(f"Fixed HTML written -> {output_path} ({len(fixed)} chars)")
    print("Removed: tpk-top-card, tpk-tabs")
    print("Kept: tpk-main-card, tpk-content, all sections")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
