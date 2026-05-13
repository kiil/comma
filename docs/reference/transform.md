---
title: "transform"
parent: "Reference"
nav_order: 1
---

# Reference: transform

Commands that rewrite existing text. All take text via pipe (preferred) or as a positional argument; all return plain text on stdout.

## `tr`

Translate text to a target language.

```
tr <target> [--from <lang>] [--formal] [--casual] [...text]
```

| Flag | Default | What |
|---|---|---|
| `target` (positional) | required | Target language — ISO code (`da`, `en`, `fr`) or name (`dansk`, `engelsk`) |
| `--from` | auto | Source language hint; auto-detected if omitted |
| `--formal` | off | Use formal register where the language has one (De-form, Sie-form, vous) |
| `--casual` | off | Use informal register (du-form, tu) |
| `...text` | — | Inline text (otherwise via pipe) |

**Example:**

```nu
"Hello" | tr da
"Hej" | tr --formal en
```

**Alias:** `,t`

## `rw`

Rewrite per a freeform instruction. Preserves meaning and concrete facts.

```
rw <instruction> [...text]
```

| Flag | Default | What |
|---|---|---|
| `instruction` (positional) | required | What to do — passed to the LLM as the rewrite rule |
| `...text` | — | Inline text (otherwise via pipe) |

**Example:**

```nu
"long convoluted sentence" | rw "shorter and clearer"
open --raw draft.md | rw "more direct, active voice"
```

**Alias:** `,r`

## `sum`

Summarize text. Default is dense prose in the source language.

```
sum [--bullets] [--max <int>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-b, --bullets` | off | Output as a bullet list instead of prose |
| `-m, --max` | model-decided | Cap on sentences (prose) or bullets |
| `...text` | — | Inline text (otherwise via pipe) |

**Example:**

```nu
open --raw article.md | sum
open --raw article.md | sum --bullets --max 5
```

**Alias:** `,s`

## `proof`

Correct spelling, grammar and punctuation. Preserves voice and structure.

```
proof [--strict] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-s, --strict` | off | Also correct awkward phrasing and unclear constructions |
| `...text` | — | Inline text (otherwise via pipe) |

**Example:**

```nu
"Jeg har set tre hunde igår" | proof
open --raw draft.md | proof | save -f draft.md
```

**Alias:** `,p`

## `tone`

Shift register/style without changing content.

```
tone <style> [...text]
```

| Flag | Default | What |
|---|---|---|
| `style` (positional) | required | Style label or freeform description |
| `...text` | — | Inline text (otherwise via pipe) |

Known styles: `formal`, `casual`, `executive`, `friendly`, `neutral`, `direct`, `diplomatic`. Any other value is passed verbatim to the model.

**Example:**

```nu
"we should meet at 2" | tone formal
"Dear Sir/Madam" | tone casual
"long technical explanation..." | tone executive
```

**Alias:** `,o`

## Behaviour shared by all commands

- Input: pipe (preferred) or positional args. Positional args are joined with spaces.
- Output: plain text on stdout. No quotes, code fences, preambles or trailing commentary. Trailing whitespace trimmed.
- Source language is preserved unless explicitly translating.
- Uses `$env.COMMA_CFG` for provider/model/tools — see [configuration](configuration.md).
