---
title: "generate"
parent: "Reference"
nav_order: 2
---

# Reference: generate

Commands that produce new text from a brief. All five accept `--notes <key>` to pull IWE context as factual ground truth.

## Shared `--notes` flags

Available on every command in this module:

| Flag | Default | What |
|---|---|---|
| `--notes <key>` | — | IWE note key to retrieve as background context |
| `--notes-depth <int>` | 2 | Inclusion-link depth ahead |
| `--notes-shape <string>` | `background` | One of `background`, `brief`, `quotes-only` |

When `--notes` is set, the retrieved markdown is prepended to the system prompt as a "research context" block with explicit instructions that the model treat it as ground truth. See [research.context](research.md#context) for the underlying retrieval.

## `draft`

Write a complete draft from a brief.

```
draft [--words <int>] [--lang <string>] [shared --notes flags] [...brief]
```

| Flag | Default | What |
|---|---|---|
| `-w, --words` | model-decided | Target word count |
| `-l, --lang` | auto (match brief) | Target output language |
| `...brief` | — | Brief inline (otherwise via pipe) |

**Example:**

```nu
"product description for rain boots" | draft --words 200
"LinkedIn post about Q3 results" | draft --lang en
"blog post about espresso" | draft --notes espresso-essentials
```

**Alias:** `,dr`

## `expand`

Turn bullets/notes/fragments into connected prose. No new facts, no invented details.

```
expand [--style <string>] [shared --notes flags] [...bullets]
```

| Flag | Default | What |
|---|---|---|
| `-s, --style` | natural prose | Format/genre — `email`, `report section`, `blog post`, etc. |
| `...bullets` | — | Bullets/fragments inline (otherwise via pipe) |

**Example:**

```nu
"- met Anna\n- talked about Q3\n- follow-up Friday" | expand --style email
```

**Alias:** `,ex`

## `title`

Propose distinct title/headline candidates.

```
title [--count <int>] [--style <string>] [shared --notes flags] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-n, --count` | 5 | Number of candidates |
| `--style` | unspecified | `neutral`, `clickbait`, `akademisk`, `SEO`, etc. |
| `...text` | — | Source text inline (otherwise via pipe) |

**Example:**

```nu
open --raw article.md | title --count 10 --style SEO
```

**Alias:** `,ti`

## `ideas`

Brainstorm distinct, concrete ideas around a topic.

```
ideas [--count <int>] [shared --notes flags] [...topic]
```

| Flag | Default | What |
|---|---|---|
| `-n, --count` | 10 | Number of ideas |
| `...topic` | — | Topic inline (otherwise via pipe) |

**Example:**

```nu
"names for a new coffee bar in Aarhus" | ideas --count 20
```

**Alias:** `,id`

## `ask`

Generate questions about a topic or text.

```
ask [--count <int>] [--kind <string>] [shared --notes flags] [...source]
```

| Flag | Default | What |
|---|---|---|
| `-n, --count` | 8 | Number of questions |
| `-k, --kind` | `open` | One of `open`, `faq`, `interview`, `socratic` |
| `...source` | — | Topic/source text inline (otherwise via pipe) |

**Example:**

```nu
open --raw whitepaper.md | ask --kind faq --count 10
"new CTO starts Monday" | ask --kind interview
```

**Alias:** `,as`

## Behaviour shared by all commands

- Output: plain text on stdout. No preamble, no markdown wrappers, no numbering on lists.
- Lists use one item per line — no bullets, no commas.
- Source language is matched unless `--lang` overrides.
- Uses `$env.COMMA_CFG` — see [configuration](configuration.md).
