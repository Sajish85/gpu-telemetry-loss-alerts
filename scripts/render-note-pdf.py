"""Render NOTE-DRAFT.md to note.pdf (CommonMark + tables via markdown-it-py -> HTML -> WeasyPrint).
Text is not altered. CommonMark is used so lists without a preceding blank line render as on GitHub.

Usage (from s1/):  .venv/bin/python scripts/render-note-pdf.py NOTE-DRAFT.md note.pdf
Needs: markdown-it-py, weasyprint (in s1/.venv) and pango (brew install pango).
"""
import sys

from markdown_it import MarkdownIt
from weasyprint import HTML

CSS = """
@page { size: A4; margin: 22mm 20mm 22mm 20mm;
        @bottom-center { content: counter(page) " / " counter(pages); font-size: 9pt; color: #555; } }
body { font-family: "Charter", "Georgia", serif; font-size: 10.5pt; line-height: 1.45; color: #111; }
h1 { font-size: 17pt; line-height: 1.25; margin: 0 0 8pt; }
h2 { font-size: 13pt; margin: 16pt 0 6pt; }
h3 { font-size: 11pt; margin: 12pt 0 4pt; }
p, li { text-align: left; }
blockquote { margin: 8pt 0; padding: 4pt 10pt; border-left: 3pt solid #999; background: #f4f4f4; }
code { font-family: "Menlo", monospace; font-size: 8.8pt; }
pre { background: #f4f4f4; padding: 6pt 8pt; font-size: 8.5pt; white-space: pre-wrap; word-wrap: break-word; }
table { border-collapse: collapse; width: 100%; font-size: 9pt; margin: 8pt 0; }
th, td { border: 0.5pt solid #888; padding: 3pt 5pt; vertical-align: top; text-align: left; }
th { background: #eaeaea; }
tr, pre, blockquote { break-inside: avoid; }
a { color: #0b4f8a; text-decoration: none; }
"""


def main(src: str, dst: str) -> None:
    with open(src, encoding="utf-8") as f:
        text = f.read()
    body = MarkdownIt("commonmark").enable("table").render(text)
    title = text.splitlines()[0].lstrip("# ").strip()
    html = (f'<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{title}</title>'
            f"<style>{CSS}</style></head><body>{body}</body></html>")
    HTML(string=html).write_pdf(dst)
    print(f"Wrote {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
