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
fetch "https://example.com" --frontmatter | iwe new -k article-source
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
fetch <url> | distill | iwe attach espresso-essentials
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

- `fetch` returns markdown text. The others (`distill`, `cite`, `context`) also return text on stdout — composable with `save`, `iwe attach`, or any nushell pipe.
- Persistence is your call. None of these commands write to IWE on their own — you pipe to `iwe attach <key>` or `iwe new -k <key>`.
- `distill` and `cite` use `$env.COMMA_CFG` (LLM-backed, no tools). See [configuration](configuration.md).
- `context` is purely an IWE wrapper plus the optional `sum` shape — no direct LLM call.
