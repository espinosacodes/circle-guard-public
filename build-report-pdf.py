#!/usr/bin/env python3
"""Build REPORTE_TALLER_2.pdf from the Markdown source with images embedded."""
import base64
import mimetypes
import pathlib
import re
import subprocess
import sys

import markdown

ROOT = pathlib.Path(__file__).parent.resolve()
MD = ROOT / "REPORTE_TALLER_2.md"
HTML = ROOT / "REPORTE_TALLER_2.html"
PDF = ROOT / "REPORTE_TALLER_2.pdf"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

CSS = """
@page { size: Letter; margin: 1.5cm 2cm; }
body {
  font-family: -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif;
  font-size: 11pt;
  color: #222;
  line-height: 1.4;
  max-width: 100%;
}
h1 { color: #1a3a5e; border-bottom: 2px solid #1a3a5e; padding-bottom: 4px; }
h2 { color: #1a3a5e; margin-top: 1.5em; border-bottom: 1px solid #ccc; padding-bottom: 2px; }
h3 { color: #2d5a87; margin-top: 1.2em; }
h4 { color: #444; }
p, li { font-size: 11pt; }
code { background: #f4f4f4; padding: 1px 4px; border-radius: 3px; font-size: 10pt; }
pre { background: #f4f4f4; padding: 8px 12px; border-radius: 4px; overflow-x: auto; font-size: 9.5pt; line-height: 1.3; }
pre code { background: transparent; padding: 0; }
table { border-collapse: collapse; margin: 8px 0; font-size: 10pt; width: 100%; }
th, td { border: 1px solid #ccc; padding: 4px 8px; text-align: left; }
th { background: #f0f4f8; }
img { max-width: 100%; border: 1px solid #ddd; border-radius: 4px; margin: 10px 0; display: block; }
em { color: #666; font-size: 10pt; }
hr { border: none; border-top: 1px solid #ccc; margin: 20px 0; }
blockquote { color: #555; border-left: 4px solid #ccc; padding-left: 12px; margin-left: 0; }
"""


def embed_image_as_data_uri(match: re.Match) -> str:
    """Replace <img src="screenshots/..."> with data URI so PDF is portable."""
    full = match.group(0)
    src = match.group(1)
    path = ROOT / src
    if not path.exists():
        print(f"[warn] image missing: {path}", file=sys.stderr)
        return full
    mime, _ = mimetypes.guess_type(str(path))
    if not mime:
        mime = "image/png"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return full.replace(f'src="{src}"', f'src="data:{mime};base64,{encoded}"')


def main() -> int:
    md_text = MD.read_text(encoding="utf-8")
    html_body = markdown.markdown(
        md_text,
        extensions=["tables", "fenced_code", "toc"],
    )
    # Embed images so PDF is single-file
    html_body = re.sub(r'<img[^>]*src="([^"]+)"[^>]*>',
                       embed_image_as_data_uri, html_body)

    full_html = f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Reporte Taller 2 — CircleGuard</title>
<style>{CSS}</style>
</head>
<body>
{html_body}
</body>
</html>"""
    HTML.write_text(full_html, encoding="utf-8")
    print(f"[ok] HTML  -> {HTML} ({HTML.stat().st_size // 1024} KB)")

    if not pathlib.Path(CHROME).exists():
        print(f"[err] Chrome not found at {CHROME}", file=sys.stderr)
        return 1

    cmd = [
        CHROME,
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--no-pdf-header-footer",
        f"--print-to-pdf={PDF}",
        f"file://{HTML}",
    ]
    print(f"[run] {' '.join(cmd[:1])} ... --print-to-pdf=…")
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr, file=sys.stderr)
        return r.returncode
    print(f"[ok] PDF   -> {PDF} ({PDF.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
