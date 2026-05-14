---
title: "Render to PDF"
parent: "How-to guides"
nav_order: 5
---

# How to render markdown to PDF

## Goal

Turn a finished markdown document into a publication-quality PDF using typst as the engine (faster and prettier than LaTeX, no LaTeX install required).

## Prerequisites

- **pandoc** in `$PATH` — `brew install pandoc`
- **typst** in `$PATH` — `brew install typst`

Both will be checked automatically and you'll get a clear error if either is missing.

## Basic recipe

```nu
open --raw article.md | to-pdf article.pdf
```

Reads `article.md`, renders to `article.pdf` using `typst` as the PDF engine.

## With metadata

```nu
open --raw article.md \
  | to-pdf article.pdf \
    --title "Espresso extraction" \
    --author "Your Name" \
    --date "2026-05-13"
```

`--title`, `--author` and `--date` become pandoc `--metadata` flags, which typst can pick up via its default template (and which most pandoc/typst templates expose somewhere on the cover or running header).

## Switch the engine

If you prefer LaTeX-based output:

```nu
open --raw article.md | to-pdf article.pdf --engine xelatex
# or
open --raw article.md | to-pdf article.pdf --engine pdflatex
# or
open --raw article.md | to-pdf article.pdf --engine weasyprint
```

Each engine has its own dependencies. Typst is recommended unless you have a specific template requirement.

## Use a custom template

```nu
open --raw article.md \
  | to-pdf article.pdf \
    --template my-template.typ
```

The template is passed straight through to pandoc's `--template` flag. For typst templates, see https://typst.app/docs/reference/foundations/template/.

## Preview only — no saved file

If you just want to look at the rendered output without keeping the PDF:

```nu
open --raw article.md | preview
```

`preview` writes to a temporary PDF and opens it in the system default app (Preview on macOS). The temp file is logged so you can grab it later if you want; otherwise it stays in `$TMPDIR` until the OS cleans up.

## Other formats

The same module covers other output formats:

| Format | Command | Notes |
|---|---|---|
| HTML | `to-html out.html` | Standalone by default; pass `--css style.css` for external stylesheet |
| DOCX | `to-docx out.docx` | Pass `--reference-doc template.docx` for custom Word styles |
| EPUB | `to-epub out.epub` | Pass `--cover-image cover.png` |
| Typst source | `to-typst out.typ` | Markdown → `.typ` so you can hand-tweak before compiling |

Or use the generic dispatcher that picks the format from the file extension:

```nu
open --raw article.md | pub out.pdf      # → to-pdf
open --raw article.md | pub out.html     # → to-html
open --raw article.md | pub out.docx     # → to-docx
```

## Compose with the full pipeline

```nu
fetch <url> | distill | iwe new "Espresso essentials"

"blog post about espresso" \
  | draft --notes espresso-essentials \
  | polish --brief "blog post about espresso" \
  | to-pdf espresso.pdf --title "Espresso essentials" --author "LK"
```

## Common issues

- **"pandoc: not found"** — install pandoc (`brew install pandoc`).
- **"typst: not found"** — install typst (`brew install typst`) or switch engine with `--engine xelatex` if you have LaTeX installed.
- **Code blocks render poorly with typst** — typst's default template handles code blocks but lacks syntax highlighting. Switch to `--engine xelatex` with a minted-aware template, or use a custom typst template that imports `codly`.
- **Tables overflow the page** — typst handles wide tables by default with auto-shrinking; for wider control, render through a custom template.

## Related

- [reference/convert](../reference/convert.md) — full flag reference for every output command
- [How to switch LLM models](switch-llm-models.md) — note that convert has nothing to do with LLMs; it is pure document conversion
