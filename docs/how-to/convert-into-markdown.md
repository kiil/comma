---
title: "Convert documents into markdown"
parent: "How-to guides"
nav_order: 6
---

# How to convert documents into markdown

## Goal

Pull external document formats (Word, PDF, EPUB, HTML, LaTeX, …) into markdown so they can flow through the rest of the comma pipeline — analyze, polish, distill, transform, render to a different format.

## Prerequisites

- **pandoc** in `$PATH` — handles html, docx, epub, odt, latex, rst, org
- **pdftotext** in `$PATH` (only for `from-pdf`) — part of poppler; `brew install poppler` on macOS

## Basic recipes

### From a Word document

```nu
from-docx report.docx
```

Returns markdown on stdout. Pipe wherever you need it:

```nu
from-docx report.docx | save -f report.md
from-docx report.docx | proof | save -f report.md
from-docx report.docx | polish --brief "quarterly update" > polished.md
```

Extract embedded images alongside the text:

```nu
from-docx report.docx --extract-media ./figures
```

### From a PDF paper

```nu
from-pdf paper.pdf
```

PDF output is *plain text*, not true markdown — pandoc cannot read PDF directly, so we fall back to `pdftotext`. Headings, tables and multi-column layouts may not survive. Still useful for downstream analysis:

```nu
from-pdf paper.pdf | distill | iwe attach research-paper
from-pdf paper.pdf | report --no-llm | to yaml
```

To preserve the original layout (columns, line breaks):

```nu
from-pdf paper.pdf --layout
```

### From an EPUB book

```nu
from-epub book.epub | save -f book.md
from-epub book.epub | sentences | length        # count sentences in the whole book
from-epub book.epub | report --lang en          # full analysis of the corpus
```

### From HTML

```nu
from-html page.html
open --raw page.html | from-html       # also works
```

Note that for live URLs you usually want [`fetch`](../reference/research.md#fetch) instead — it uses Mozilla Readability to extract just the article content, where `from-html` keeps everything in the HTML body.

### From other formats

| Format | Command | Input type |
|---|---|---|
| LaTeX | `from-latex paper.tex` or piped | text |
| reStructuredText | `from-rst manual.rst` or piped | text |
| Org-mode | `from-org notes.org` or piped | text |
| LibreOffice ODT | `from-odt document.odt` | binary |

All text-format commands accept either a file path positional or piped text. Binary formats require a file path.

## Round-trip with the to-* commands

The from-* and to-* commands are inverses. You can round-trip a document through markdown for any transformation that needs structural rewriting:

```nu
# Open a Word doc, polish, re-render as Word with a custom template
from-docx draft.docx \
  | polish --level editorial --brief "Q3 review" \
  | to-docx polished.docx --reference-doc company-style.docx

# Open an EPUB, translate every chapter, build a new EPUB
from-epub book-en.epub \
  | tr da \
  | to-epub book-da.epub --title "Bog på dansk" --author "Translator Name"

# Open a LaTeX paper, summarize, output a PDF brief
from-latex paper.tex \
  | sum --max 10 \
  | to-pdf summary.pdf --title "Paper summary"
```

## Working with extracted images

The binary-format commands (`from-docx`, `from-epub`, `from-odt`) embed images inside the file. Use `--extract-media <dir>` to write them to disk alongside the markdown:

```nu
from-docx report.docx --extract-media ./media | save -f report.md
ls ./media         # check what was extracted
```

The output markdown will contain `![](media/image1.png)`-style references pointing at the extracted files.

## Caveats

- **PDF quality varies hugely.** A clean LaTeX-generated PDF extracts well. A scanned image of a printed page extracts as garbage — you would need OCR (`tesseract`) first, which is out of comma's scope.
- **Tables in DOCX/ODT** convert to markdown tables, which look ugly inline. Run `from-docx | proof` to normalize them, or accept that markdown tables aren't pretty.
- **EPUB fidelity depends on the source.** A well-structured EPUB with semantic markup extracts beautifully; a DRM-stripped, image-heavy EPUB may produce noise.
- **LaTeX with custom commands** may need pandoc to be told about your packages. For complex documents, expect to clean up the result manually.

## Related

- [reference/convert](../reference/convert.md) — full flag reference for every from-* and to-* command
- [How to render to PDF](render-to-pdf.md) — the inverse direction
- [Tutorial 02 — research-to-publish pipeline](../tutorials/02-the-research-pipeline.md) — sees from-* commands as the natural entry point when capture is a file rather than a URL
