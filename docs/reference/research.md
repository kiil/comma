---
title: "research"
parent: "Reference"
nav_order: 5
---

# Reference: research

Commands for capturing material, distilling it into structured notes, and bridging to IWE for note persistence.

## `fetch`

Fetch a URL and extract the main content via Mozilla Readability (using the `reader` binary).

```
fetch <url> [--js] [--no-extract] [--frontmatter] [--image-mode <string>] [--wait <duration>]
```

| Flag | Default | What |
|---|---|---|
| `url` | required | URL to fetch |
| `--js` | off | Use headless Chromium (`http browse` plugin) for JS-rendered pages |
| `--no-extract` | off | Skip Readability extraction — return full-page markdown |
| `--frontmatter` | off | Prepend YAML frontmatter (title, source, captured, language, published, author, …) via `query webpage-info` |
| `--image-mode` | `none` | One of `none`, `ansi`, `ansi-dither`, `kitty`, `sixel` |
| `--wait` | 2sec | JS-rendering wait time (only with `--js`) |

**Dependencies:**

- `reader` — `go install github.com/mrusme/reader@latest`
- `nu_plugin_query` — used by `--frontmatter` (and by `meta`, `links`, `feeds`)
- For `--js`: `nu_plugin_browse` plus Chrome/Chromium

**Returns:** markdown on stdout. With `--frontmatter`, a `---`-fenced YAML block is prepended.

**Example:**

```nu
fetch "https://example.com/article"
fetch "https://spa.example.com/page" --js
fetch "https://example.com" --no-extract                  # raw markdown without Readability
fetch "https://example.com" --frontmatter | iwe new "Article source"
```

**Alias:** `,fe`

## `meta`

Structured metadata for a URL via `query webpage-info`. Returns a flat record with the most useful fields: title, source, language, description, published, modified, author, feed, plus raw `opengraph` and `schema_org`.

```
meta <url> [--js] [--wait <duration>]
```

| Flag | Default | What |
|---|---|---|
| `url` | required | URL to inspect |
| `--js` | off | Use headless Chromium for JS-rendered pages |
| `--wait` | 2sec | JS-rendering wait time |

**Dependencies:** `nu_plugin_query`.

**Example:**

```nu
meta "https://example.com/article" | reject opengraph schema_org
meta "https://example.com" --js | to yaml
```

**Alias:** `,mt`

## `links`

Extract outbound links from a page. Returns a table with `url` and `text` columns.

```
links <url> [--external] [--js] [--wait <duration>]
```

| Flag | Default | What |
|---|---|---|
| `url` | required | URL to scan |
| `--external` | off | Filter to links pointing outside the page's own host |
| `--js` | off | Use headless Chromium |
| `--wait` | 2sec | JS-rendering wait time |

**Dependencies:** `nu_plugin_query`.

**Example:**

```nu
links "https://example.com/article" --external | first 10
```

**Alias:** `,lk`

## `feeds`

Extract advertised RSS/Atom feed URLs from a page. Combines `webpage-info`'s primary feed with any `<link rel="alternate" type="application/...+xml">` references. Relative URLs are resolved against the input host.

```
feeds <url> [--js] [--wait <duration>]
```

| Flag | Default | What |
|---|---|---|
| `url` | required | URL to scan |
| `--js` | off | Use headless Chromium |
| `--wait` | 2sec | JS-rendering wait time |

**Dependencies:** `nu_plugin_query`.

**Example:**

```nu
feeds "https://blog.rust-lang.org/"
# → https://blog.rust-lang.org/feed.xml
```

Empty list means the page does not advertise a feed in its HTML — the site may still have one (e.g. at `/feed.xml` or `/atom.xml`) but you would need to check directly.

**Alias:** `,fd`

## `distill`

Bearbejd raw captured text (article, transcript, notes) into a structured study note via LLM.

```
distill [...text]
```

Output structure (fixed):

```markdown
## Claims
- <single declarative claim made by the source>

## Quotes
> <verbatim quote>
(<context: who/where>)

## Open questions
- <question the source raises but does not answer>

## Keywords
<5–15 comma-separated topical tags, lowercase>
```

Matches source language for claims, quotes, questions; keywords use source language too.

**Example:**

```nu
fetch <url> | distill | iwe new "Espresso essentials"
open --raw transcript.md | distill
```

**Alias:** `,di`

## `cite`

Extract verbatim quotes about a specific topic.

```
cite <topic> [--count <int>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `topic` | required | What the extracted quotes should be about |
| `-n, --count` | 10 | Max number of quotes |

Output: markdown blockquotes with brief context lines. If no relevant quotes, returns exactly `no relevant quotes`.

**Example:**

```nu
open --raw transcript.md | cite "economic growth"
fetch <url> | cite "automation" --count 5
```

**Alias:** `,ci`

## `context`

Retrieve a note hierarchy from IWE and shape it for use as LLM context. This is the bridge command used internally by `--notes` flags in `generate.nu`.

```
context <key> [--depth <int>] [--parent-context <int>] [--max-chars <int>] [--shape <string>]
```

| Flag | Default | What |
|---|---|---|
| `key` | required | IWE note key (slug) |
| `-d, --depth` | 2 | Inclusion-link depth (children retrieved) |
| `-c, --parent-context` | 1 | Levels of parent context (up) |
| `--max-chars` | 16000 | Hard cap (~4000 tokens) — truncates with `[…truncated…]` marker |
| `--shape` | `background` | One of `background`, `brief`, `quotes-only` |

**Shapes:**

- `background` — raw markdown from `iwe retrieve` (no transformation)
- `brief` — runs the retrieval through `sum --max 10` to compress
- `quotes-only` — extracts only blockquote lines (`> `) from the retrieval

**Dependencies:**

- `iwe` — see https://iwe.md
- Must be run from inside an IWE workspace (a directory with `.iwe/`)

**Example:**

```nu
context espresso-essentials                       # raw retrieval
context espresso-essentials --depth 3             # deeper
context espresso-essentials --shape brief         # compressed
context espresso-essentials --shape quotes-only   # just the quotes
```

**Alias:** `,cx`

## Behaviour shared by all commands

- `fetch` returns markdown text. The others (`distill`, `cite`, `context`) also return text on stdout — composable with `save`, `iwe new`, or any nushell pipe.
- Persistence is your call. None of these commands write to IWE on their own — you pipe to `iwe new "<Title>"` to create a document (slug is derived from the title). To link an existing document into a configured target (a daily log, an inbox, …), follow up with `iwe attach -k <slug> --to <action>` — `<action>` is a name from your `.iwe/config.toml`.
- `distill` and `cite` use `$env.COMMA_CFG` (LLM-backed, no tools). See [configuration](configuration.md).
- `context` is purely an IWE wrapper plus the optional `sum` shape — no direct LLM call.

## `iwe attach`: the linking primitive

The IWE CLI's `attach` subcommand is not what its name might suggest in everyday usage — it does *not* take stdin content and create a note. It is a *linking* command: given an existing source document and a configured *attach action* in `.iwe/config.toml`, it adds the source as a block reference under the target document the action resolves to.

A typical `.iwe/config.toml` action looks like:

```toml
[actions.daily]
type = "attach"
key_template = "daily/{{today}}"
title = "{{today}}"
```

With that in place, the two-step capture pattern is:

```nu
fetch <url> | iwe new "Coffee deep dive"            # creates coffee-deep-dive.md
iwe attach -k coffee-deep-dive --to daily           # links it under daily/2026-05-14
```

This is useful if you keep a running daily log of everything you read. The block reference points at the source note; the source remains its own first-class document.

Without configured actions, `iwe attach` has nothing to attach to and you do not need it — `iwe new` alone is the capture primitive.

## `iwe squash` and `iwe inline`: assembly primitives

Two further IWE CLI subcommands matter for the comma flow because they handle the "I have many notes; assemble them into one document" case. Both operate on inclusion links, but with different intent.

### `iwe squash <key>` — non-destructive consolidation

Follows every inclusion link from the starting document, recursively to a configurable depth, and emits one consolidated markdown document on stdout. Headings are renumbered so the resulting hierarchy is consistent. The source files are not modified.

```
iwe squash <KEY> [-d <depth>]
```

| Flag | Default | What |
|---|---|---|
| `KEY` | required | starting document |
| `-d, --depth` | 2 | how many levels of inclusion links to follow |

**The use case:** you have written a *skeleton* article in IWE where each section is an inclusion link to a research note. `iwe squash` materializes the skeleton into the final assembled text — pipe it into `polish`, `to-pdf`, or anywhere else.

```nu
# Capture and distill three sources
fetch <url1> | distill | iwe new "Extraction basics"
fetch <url2> | distill | iwe new "Grind size"
fetch <url3> | distill | iwe new "Temperature"

# Author a skeleton with inclusion links
iwe new "Espresso article" --content "# Espresso essentials

## Extraction
[extraction-basics]

## Grind
[grind-size]

## Temperature
[temperature]
"

# Squash to a single consolidated draft
iwe squash espresso-article | save -f draft.md

# Continue the comma pipeline
open --raw draft.md | polish --brief "Espresso essentials article" | to-pdf out.pdf
```

This is the alternative to `draft --notes` when you want to compose from your own notes deterministically rather than ask an LLM to synthesize across them. See [How to ground generation in research notes](../how-to/ground-generation-in-research.md) for both patterns side by side.

### `iwe inline <key>` — surgical, destructive

Replaces a single inclusion link with the actual content of the referenced document, in place in the source file. By default, the referenced document is then *deleted* and any other references to it are cleaned up across the graph.

```
iwe inline <KEY> [--reference <KEY> | --block <N>]
                 [--keep-target] [--as-quote] [--dry-run]
```

| Flag | Default | What |
|---|---|---|
| `KEY` | required | document containing the reference to inline |
| `--reference` | — | which referenced document to inline (key or title, case-insensitive partial match) |
| `--block` | — | select reference by 1-indexed position |
| `--list` | off | list every inclusion link in the document with its number |
| `--keep-target` | off | preserve the referenced document instead of deleting it |
| `--as-quote` | off | embed as a markdown blockquote instead of a section |
| `--dry-run` | off | print result without writing |

Use this when you genuinely want to merge two specific documents and remove the source — for example, promoting an inbox note into a section of a longer write-up and discarding the inbox draft. **The destructive default is dangerous; use `--dry-run` first and `--keep-target` if you are unsure.**

For most assembly work, prefer `iwe squash`. `inline` is for one-at-a-time refactoring, not for building a draft.

### When to use which

| Goal | Command |
|---|---|
| LLM writes an article informed by your notes | `draft --notes <key>` |
| Assemble your own notes in a skeleton order, non-destructively | `iwe squash <skeleton-key>` |
| Merge two specific documents and delete the source | `iwe inline <key> --reference <other>` |
| Preview what content would land where before assembly | `iwe squash --depth 1` or `iwe inline --dry-run` |
