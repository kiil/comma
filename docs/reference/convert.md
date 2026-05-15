---
title: "convert"
parent: "Reference"
nav_order: 8
---

# Reference: convert

Render markdown to other document formats on disk via pandoc and (for PDF) typst. All commands take markdown via pipe and write to a file.

For posting finished output to external platforms via API (LinkedIn, Drupal, etc.), see [publish](publish.md) — that is a separate, currently reserved module.

## Dependencies

- `pandoc` — universal document converter, required by all commands except `typst-compile`
- `typst` — default PDF engine; required by `to-pdf` (default), `preview` (default), `typst-compile`

Each command runs a `require <cmd>` check at start; missing dependencies produce a clear error pointing at `brew install <cmd>`.

## Shared metadata flags

All commands accept these where relevant:

| Flag | What |
|---|---|
| `--title` | Becomes pandoc `--metadata title=…` |
| `--author` | Becomes pandoc `--metadata author=…` |
| `--date` | Becomes pandoc `--metadata date=…` |

## `to-pdf`

Markdown → PDF via pandoc + typst (default engine).

```
to-pdf <out> [--title <s>] [--author <s>] [--date <s>]
             [--template <path>] [--engine <string>]
             [...text]
```

| Flag | Default | What |
|---|---|---|
| `out` | required | Output file path (typically `.pdf`) |
| `-t, --template` | — | pandoc/typst template path |
| `-e, --engine` | `typst` | One of `typst`, `xelatex`, `pdflatex`, `weasyprint` |

**Alias:** `,pd`

## `to-html`

Markdown → standalone HTML5.

```
to-html <out> [--title <s>] [--author <s>] [--date <s>]
              [--css <path>] [--template <path>] [--no-standalone]
              [...text]
```

| Flag | Default | What |
|---|---|---|
| `out` | required | Output file path |
| `--css` | — | External stylesheet path |
| `-t, --template` | — | pandoc template |
| `--no-standalone` | off | Emit a fragment instead of a full document |

**Alias:** `,hl`

## `to-docx`

Markdown → Word DOCX.

```
to-docx <out> [--title <s>] [--author <s>] [--date <s>]
              [--reference-doc <path>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `out` | required | Output file path |
| `--reference-doc` | — | DOCX template defining custom styles |

**Alias:** `,dx`

## `to-epub`

Markdown → EPUB3.

```
to-epub <out> [--title <s>] [--author <s>] [--date <s>]
              [--cover-image <path>] [--css <path>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `out` | required | Output file path |
| `--cover-image` | — | Path to cover image |
| `--css` | — | External stylesheet |

**Alias:** `,ep`

## `to-typst`

Markdown → Typst source (`.typ`). Useful when you want to hand-tweak before compiling.

```
to-typst <out> [--title <s>] [--author <s>] [--date <s>] [...text]
```

**Alias:** `,tp`

## `typst-compile`

Compile an existing `.typ` source to PDF using typst directly (no pandoc).

```
typst-compile <input> <output> [--root <path>]
```

| Flag | Default | What |
|---|---|---|
| `input` | required | `.typ` source file |
| `output` | required | `.pdf` output file |
| `--root` | — | Root directory for relative includes |

No alias.

## `preview`

Render to a temporary PDF and open in the system default viewer.

```
preview [--title <s>] [--author <s>] [--engine <string>] [...text]
```

The temporary file path is logged on stderr; the OS cleans up `$TMPDIR` on its own schedule.

**Alias:** `,pv`

## `pub`

Generic dispatcher — picks the format from the output file extension.

```
pub <out> [--title <s>] [--author <s>] [--date <s>]
          [--template <path>] [--engine <string>] [...text]
```

| Extension | Dispatches to |
|---|---|
| `.pdf` | `to-pdf` |
| `.html`, `.htm` | `to-html` |
| `.docx` | `to-docx` |
| `.epub` | `to-epub` |
| `.typ` | `to-typst` |

Errors on any other extension.

The command is named `pub` for backwards compatibility — the name originates from when this module was called `publish`. The `pub` alias and command are stable.

## from-* commands

The inverse direction: convert other document formats into markdown. All return markdown on stdout — pipe to `save`, to another comma command, or to `iwe new`.

Text formats accept either a file path or piped text. Binary formats require a file path because they can't be passed through a pipe meaningfully.

All commands accept `--wrap (-w) <string>` to control pandoc's line-wrapping (default: `none`, meaning no soft wrapping in the output markdown).

### `from-html`

HTML → markdown.

```
from-html [file] [--wrap <string>]
```

Accepts a `.html` file path or piped HTML.

### `from-latex`

LaTeX → markdown.

```
from-latex [file] [--wrap <string>]
```

Accepts a `.tex` file path or piped LaTeX.

### `from-rst`

reStructuredText → markdown.

```
from-rst [file] [--wrap <string>]
```

Accepts a `.rst` file path or piped reST.

### `from-org`

Org-mode → markdown.

```
from-org [file] [--wrap <string>]
```

Accepts a `.org` file path or piped org-mode.

### `from-docx`

Word DOCX → markdown.

```
from-docx <file> [--wrap <string>] [--extract-media <path>]
```

| Flag | Default | What |
|---|---|---|
| `file` | required | input `.docx` file |
| `--extract-media` | — | directory to write embedded images into |

### `from-epub`

EPUB → markdown.

```
from-epub <file> [--wrap <string>] [--extract-media <path>]
```

### `from-odt`

LibreOffice/OpenOffice ODT → markdown.

```
from-odt <file> [--wrap <string>] [--extract-media <path>]
```

### `from-pdf`

PDF → plain text via `pdftotext` (from poppler). Pandoc cannot read PDF directly, so the output is plain text rather than true markdown — headings, tables and multi-column layouts may not survive. Still useful as input to downstream comma commands like `analyze`, `polish` or `distill`.

```
from-pdf <file> [--layout]
```

| Flag | Default | What |
|---|---|---|
| `file` | required | input `.pdf` file |
| `--layout` | off | preserve original column layout (pass `-layout` to pdftotext) |

**Dependency:** `pdftotext` (from poppler — `brew install poppler` on macOS).

## Composition examples

The `from-*` commands compose with the rest of comma in obvious ways:

```nu
# Read a Word doc, polish it, render to PDF
from-docx draft.docx | polish --brief "team update" | to-pdf final.pdf --title "Team update"

# Distill a PDF paper into a structured IWE note
from-pdf paper.pdf | distill | iwe new "Research paper"

# Analyze an EPUB book
from-epub book.epub | report --no-llm | to yaml | save -f analysis.yaml

# Convert legacy reStructuredText to markdown and proofread
from-rst manual.rst | proof | save -f manual.md
```

**Alias:** `,pb`

## Behaviour shared by all commands

- Reads markdown from pipe (preferred) or `...text` positional.
- Rejects non-string pipe input (e.g. `open file.md` AST) with an error suggesting `open --raw`.
- Writes to the specified output file.
- Prints a success line on success: `wrote <path>`.
