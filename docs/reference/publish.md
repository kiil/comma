---
title: "publish"
parent: "Reference"
nav_order: 7
---

# Reference: publish

Render markdown to publishable formats via pandoc and (for PDF) typst. All commands take markdown via pipe and write to a file.

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

The command is named `pub` rather than `publish` because nushell does not allow a module to export a command named the same as the module file.

**Alias:** `,pb`

## Behaviour shared by all commands

- Reads markdown from pipe (preferred) or `...text` positional.
- Rejects non-string pipe input (e.g. `open file.md` AST) with an error suggesting `open --raw`.
- Writes to the specified output file.
- Prints a success line on success: `skrev <path>` (Danish — yes, that's a minor quirk).
