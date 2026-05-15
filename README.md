# comma

An opinionated language overlay for [yoke](https://github.com/cablehead/yoke) — a stateless toolbox of nushell commands for working with text. Each command takes text in, returns text out, and is ready to pipe into the next one. No conversation context, no markdown decoration, no LLM scaffolding to manage.

Where `yolay` is a general-purpose agent REPL, `comma` is its opposite: a tight set of single-purpose commands organized into a clear pipeline — research, generate, analyze, transform, publish.

## Install

`comma` is a nushell directory module. Drop it anywhere and load it as an overlay:

```nu
overlay use /path/to/comma
```

Or, if you keep it in a fixed location, add the overlay to your `config.nu`.

After loading you'll see:

```
comma overlay loaded · gemini/gemini-3.1-flash-lite-preview
transform · generate · analyze — ,? for list
```

Type `,?` (or `status`) at any time for the current command inventory.

For longer documentation, see [`docs/`](docs/) — organized as tutorials, how-to guides, reference, and explanation following the [Diátaxis framework](https://diataxis.fr/).

## Dependencies

Required:

- **nushell** 0.106+
- **yoke** — provides the underlying LLM call interface

Optional, per module:

| Module | Tool | Purpose |
|---|---|---|
| convert | `pandoc` | Universal document converter (used by every `to-*` and most `from-*`) |
| convert | `typst` | Default PDF engine (faster, nicer typography than LaTeX) |
| convert | `pdftotext` | Required by `from-pdf`. Part of poppler — `brew install poppler` |
| research | `reader` | Mozilla Readability port in Go for clean article extraction. `go install github.com/mrusme/reader@latest` |
| research | `nu_plugin_query` | CSS-selector and `webpage-info` extraction. Used by `meta`, `links`, `feeds`, and `fetch --frontmatter`. `cargo install nu_plugin_query && plugin add ~/.cargo/bin/nu_plugin_query` |
| research | `nu_plugin_browse` | Headless Chromium for JS-rendered pages. Only needed for `--js` flag on `fetch`/`meta`/`links`/`feeds`. `cargo install nu_plugin_browse && plugin add ~/.cargo/bin/nu_plugin_browse` |
| research | `iwe` | Markdown knowledge graph used as note persistence layer. https://iwe.md |
| validate | network | `factcheck` and `quotes` use `web_search` |
| feeds | `blog` (blogtato) | Default RSS/Atom backend. `cargo install blogtato` |
| feeds | `fzf` | Used by `pick` for interactive post selection |

Commands that need a missing tool fail with a clear error pointing at the install command. The module loads regardless.

## The pipeline

The five modules form a left-to-right pipeline. You rarely use all of them in one chain, but the flow is the mental model:

```
research → generate → analyze/validate → transform → convert → publish
```

- **research** captures, distills and supplies factual context
- **generate** writes new text from a brief, optionally grounded in research
- **analyze** inspects existing text — statistics, frequencies, classification
- **validate** verifies text against reality — fact-checking, quote verification
- **transform** rewrites existing text — translation, proofreading, tone shifts
- **convert** renders finished text to PDF, HTML, DOCX, EPUB files on disk
- **publish** (reserved) will post to external platforms via API

There is also `polish` (in `pipeline.nu`) which orchestrates analyze + transform iteratively to refine a draft until it converges on quality thresholds.

## Quick start

```nu
# Translate
"Hello, world" | tr da

# Proofread
"Jeg har set tre hunde igår" | proof

# Summarize a file
open --raw artikel.md | sum --bullets --max 5

# Statistical report on a text
open --raw artikel.md | report --lang da --top 10

# Fetch and distill a web article into a study note
fetch "https://example.com/article" | distill

# Draft something using IWE notes as factual ground truth
"LinkedIn post about automation" | draft --notes automation-essentials

# Iteratively polish a draft to publication quality
open --raw draft.md | polish --level editorial --brief "blog post about espresso"

# Render to PDF
open --raw final.md | to-pdf final.pdf --title "Espresso" --author "LK"
```

## Modules

### transform.nu — rewrite existing text

| Command | Alias | What |
|---|---|---|
| `tr <target>` | `,t` | Translate to a target language (ISO code or name) |
| `rw <instruction>` | `,r` | Rewrite per a freeform instruction |
| `sum` | `,s` | Summarize as prose or bullets |
| `proof` | `,p` | Correct spelling, grammar, punctuation |
| `tone <style>` | `,o` | Shift tone (formal, casual, executive, friendly, …) |

### generate.nu — produce new text from a brief

All five commands accept `--notes <key>` to pull IWE context as factual background.

| Command | Alias | What |
|---|---|---|
| `draft` | `,dr` | Complete draft from a brief |
| `expand` | `,ex` | Bullets/notes → connected prose |
| `title` | `,ti` | Propose title candidates |
| `ideas` | `,id` | Brainstorm distinct ideas |
| `ask` | `,as` | Generate questions (open / faq / interview / socratic) |

### analyze.nu — inspect text

Split into deterministic (cheap, offline) and LLM-backed (uses tools, costs tokens).

**Deterministic:**

| Command | Alias | What |
|---|---|---|
| `stats` | `,st` | Lines, words, chars, sentences, paragraphs, avg word length |
| `freq` | `,fq` | Word frequency with built-in EN/DA stopword sets |
| `ngrams` | `,ng` | Bigram/trigram frequency |
| `kwic <keyword>` | `,kc` | Keyword-in-context concordance |
| `lix` | `,lx` | Lix readability score (Scandinavian standard) |
| `repeats` | `,rp` | Repeated n-gram phrases — catches accidental duplication |
| `compare <other>` | `,cp` | Distinctive words in A vs B via smoothed log-odds |
| `hapax` | `,hp` | Words appearing exactly once |
| `ttr` | `,tt` | Type-token ratio (lexical richness) |
| `similar <other>` | `,sl` | Jaccard similarity via k-shingles |
| `sentences` | `,sn` | Split text into sentences |
| `paragraphs` | `,pa` | Split text into paragraphs |
| `extract --kind url\|email\|hashtag\|mention` | `,xt` | Regex extraction |
| `report` | `,rt` | Combined report: stats + freq + lix + ttr + sentiment + keywords + readability + … |

**LLM-backed** (uses `gemini-3.1-flash-lite` with no tools by default; override via `$env.COMMA_ANALYZE_CFG`):

| Command | Alias | What |
|---|---|---|
| `detect` | `,de` | Language ID (ISO code or English name) |
| `sentiment` | `,se` | Positive / neutral / negative, optional score |
| `keywords` | `,kw` | Top-N key phrases |
| `entities` | `,en` | Named entities with type tags |
| `readability` | `,rd` | Qualitative reading level + audience |
| `classify <labels>` | `,cl` | Pick best-fit label(s) |

### validate.nu — verify text against reality

Uses `gemini-3-pro-preview` with `web_search,nu` tools by default (override via `$env.COMMA_VALIDATE_CFG`). These commands need real web lookups — without them they would just hallucinate citations.

| Command | Alias | What |
|---|---|---|
| `factcheck` | `,fc` | Verify claims against web sources |
| `quotes` | `,qu` | Verify quotation wording and attribution |
| `claims` | `,cm` | Extract distinct claims (preprocessing for factcheck) |

### research.nu — capture, distill, bridge to IWE

| Command | Alias | What |
|---|---|---|
| `fetch <url>` | `,fe` | Mozilla Readability extraction via reader → markdown (`--frontmatter` adds YAML preamble) |
| `meta <url>` | `,mt` | Structured page metadata via `query webpage-info` |
| `links <url>` | `,lk` | Outbound links (`--external` to filter to off-host) |
| `feeds <url>` | `,fd` | RSS/Atom feeds advertised by the page |
| `distill` | `,di` | Raw text → structured study note (claims, quotes, open questions, keywords) |
| `cite <topic>` | `,ci` | LLM-extract verbatim quotes about a topic |
| `context <key>` | `,cx` | `iwe retrieve` + prompt-shaping for generate |
| `bibliography <key>` | `,bi` | Markdown Sources block from IWE-note frontmatter (provenance for a draft) |

All commands return markdown on stdout. Persistence is your call — pipe to `iwe new "<Title>"` (which slugifies the title into the filename). Use `iwe attach -k <slug> --to <action>` afterwards if you want to link the new note into a configured target like a daily log or inbox.

### iwe.nu — wrappers around the IWE CLI

Thin wrappers that reshape IWE's output into nu records/tables and accept piped input where it makes sense. Where research.nu already wraps a specific iwe operation with comma-flavoured intent (`context` over retrieve, `bibliography` over the hierarchy), those stay there. iwe.nu is the generic-wrapper layer.

| Command | What |
|---|---|
| `iwe-init` | Initialize the current directory as an IWE workspace |
| `iwe-new <title>` | Create a note (content from pipe, `--content`, or stdin) |
| `iwe-find [query]` | Search documents → table |
| `iwe-count [...filter]` | Count matching documents → int |
| `iwe-tree [--key <k>]` | Document hierarchy as nested records |
| `iwe-stats` | Workspace statistics → record |
| `iwe-retrieve <key>` | Raw retrieval with depth/context/format |
| `iwe-squash <key>` | Assemble a skeleton document into one consolidated markdown |
| `iwe-attach -k <key> --to <action>` | Link to a configured target (daily log, inbox, …) |
| `iwe-rename`, `iwe-delete`, `iwe-normalize` | Refactoring/maintenance |

All commands prefixed `iwe-` to avoid colliding with existing comma commands (`stats`, `extract`) and to make their target explicit.

### feeds.nu — manage RSS/Atom subscriptions

Pluggable feed-reader wrapper. Default backend is [blogtato](https://github.com/kantord/blogtato) (`cargo install blogtato`); switch via `$env.COMMA_FEEDS_PROVIDER`.

| Command | What |
|---|---|
| `subscribe <url>` | Add a feed |
| `unsubscribe <key>` | Remove a feed by URL or shorthand |
| `subs` | List subscriptions as a table |
| `sync` | Fetch updates from all feeds |
| `posts [...query]` | Query posts as a table (provider query language) |
| `unread [...query]` | Shortcut for `posts .unread` |
| `latest [...query]` | Most recent matching post as a record |
| `find-post <needle>` | Filter posts by title substring (case-insensitive) |
| `pick [...query]` | Interactive fzf picker; returns the chosen post record |
| `open-post <id>` | Open in browser (also accepts a piped record/string) |
| `mark-read <id>` | Mark read; returns the URL (also accepts piped input) |
| `mark-unread <id>` | Mark unread (also accepts piped input) |
| `import-opml <file>` / `export-opml` | OPML in/out |

Composes with the rest of comma. The shorthand handling is transparent — pipe a record through and the action commands extract the right letter automatically.

```nu
# Capture every unread post from the last week into IWE notes
unread 1w.. | each {|p| fetch $p.link | distill | iwe new $p.title }

# Pick interactively, then act on the chosen post
pick .unread | open-post
pick @shds 1w.. | mark-read | fetch $in | distill | iwe new "Captured"

# Latest of something, automatically piped to actions
latest .unread | mark-read
latest @shds | open-post
```

The single-letter shorthand (`a`, `s`, `d`, …) blogtato uses is position-based and session-scoped; comma extracts it from records on the fly. The stable `id` field is preserved on records for deduplication purposes but is not what blog accepts for actions. See [reference/feeds](docs/reference/feeds.md) for the full caveat.

### pipeline.nu — iterative critic loop

| Command | Alias | What |
|---|---|---|
| `polish` | `,po` | Generate-or-take-draft, critique with deterministic + LLM critics, patch findings, repeat until convergence |

`polish` runs in three levels:

- `light` — `proof` + `lix` thresholds
- `editorial` (default) — adds `repeats`, `readability`
- `publication` — adds `factcheck` and `quotes` as warnings (not auto-fixes)

Output is the polished text on stdout. The revision log and any warnings go to stderr so pipes stay clean.

### convert.nu — convert between file formats

| Command | Alias | What |
|---|---|---|
| `to-pdf <out>` | `,pd` | Markdown → PDF via pandoc + typst (default engine) |
| `to-html <out>` | `,hl` | Markdown → standalone HTML5 |
| `to-docx <out>` | `,dx` | Markdown → Word DOCX |
| `to-epub <out>` | `,ep` | Markdown → EPUB3 |
| `to-typst <out>` | `,tp` | Markdown → Typst source — tweak before compile |
| `typst-compile <in> <out>` | — | Direct `.typ` → `.pdf` without pandoc |
| `preview` | `,pv` | Render to temp PDF and open in default viewer |
| `pub <out>` | `,pb` | Generic to-* dispatch by output file extension |
| `from-html [file]` | — | HTML → markdown |
| `from-docx <file>` | — | Word DOCX → markdown |
| `from-epub <file>` | — | EPUB → markdown |
| `from-odt <file>` | — | LibreOffice ODT → markdown |
| `from-latex [file]` | — | LaTeX → markdown |
| `from-rst [file]` | — | reStructuredText → markdown |
| `from-org [file]` | — | Org-mode → markdown |
| `from-pdf <file>` | — | PDF → plain text (via `pdftotext`) |

The `to-*` commands accept `--title`, `--author`, `--date` for pandoc metadata. PDF takes `--engine typst\|xelatex\|pdflatex\|weasyprint` and `--template <path>`.

The `from-*` commands return markdown on stdout. Text formats (html, latex, rst, org) take an optional file path or read from a pipe; binary formats (docx, epub, odt, pdf) require a file path.

### publish.nu — post to external platforms (reserved)

Reserved module. Will hold commands that publish finished output to platforms via API (LinkedIn, Drupal, Medium, Mastodon, etc.). No commands exported yet.

## Full pipeline example

```nu
# 1. Capture and distill two sources into separate study notes
fetch "https://example.com/espresso-extraction" | distill | iwe new "Espresso extraction"
fetch "https://example.com/grind-size-science"  | distill | iwe new "Grind size science"

# 2. (Optional) organize in IWE — open espresso-essentials.md and add
#    inclusion links to the two notes you just created, so a single
#    --notes key pulls both as children:
#
#    # Espresso essentials
#    [espresso-extraction]
#    [grind-size-science]
#
#    Or use a configured attach action in .iwe/config.toml to automate this.

# 3. Draft a blog post grounded in the research
"Blog post about espresso extraction and grind size, for home brewers" \
    | draft --notes espresso-essentials --notes-depth 2 \
    | save -f draft.md

# 4. Iteratively refine until quality thresholds are met
open --raw draft.md \
    | polish --level editorial --brief "Blog post about espresso extraction and grind size, for home brewers" --verbose \
    > polished.md

# 5. Render as PDF
open --raw polished.md | to-pdf espresso.pdf --title "Espresso essentials" --author "LK"
```

## Configuration

### Default models

`comma` uses different LLM configs per module to match each module's needs:

| Module | Provider | Model | Tools | Override via |
|---|---|---|---|---|
| transform, generate, research | gemini | gemini-3.1-flash-lite-preview | none | `$env.COMMA_CFG` |
| analyze (LLM commands) | gemini | gemini-3.1-flash-lite | none | `$env.COMMA_ANALYZE_CFG` |
| validate | gemini | gemini-3-pro-preview | web_search, nu | `$env.COMMA_VALIDATE_CFG` |

The validate module has its own stronger model and tools enabled because `factcheck` and `quotes` need real `web_search` to do anything more than hallucinate citations.

Change the global default for the session:

```nu
model claude-sonnet-4-6 --provider anthropic
```

Or set directly:

```nu
$env.COMMA_CFG = {provider: openai, model: gpt-4o, tools: none}
```

Override analyze separately:

```nu
$env.COMMA_ANALYZE_CFG = {provider: anthropic, model: claude-sonnet-4-6, tools: web_search}
```

### IWE workspace

Run `research.context` and any `--notes <key>` flag from inside an IWE-initialized directory (`iwe init` to set one up). The note keys come from your IWE workspace; comma does not maintain its own notebook.

## Design principles

1. **Stateless commands, optional stateful filesystem.** Every command is `text in → text out`. Persistence lives in IWE markdown files you control, not in opaque comma state.

2. **Pipe-first.** Pipeline input is the primary input. Positional arguments exist for short inline strings only. Output is always plain text on stdout (records where structure helps); logging goes to stderr.

3. **Determinism where possible.** Word frequency, n-grams, Lix, readability metrics, stopword filtering, regex extraction — all are pure nushell, reproducible, free. LLMs are used only where they genuinely add value (translation, proofreading, classification under ambiguity, etc.).

4. **Minimal magic.** Commands wrap external tools (`reader`, `pandoc`, `typst`, `iwe`) thinly. The wrappers don't fight the underlying tools — they expose just enough surface to make the pipeline ergonomic.

5. **Patch, don't redraft.** The `polish` critic loop applies targeted fixes per finding rather than regenerating the entire text. Three small diffs beat one large rewrite.

6. **Anchor against drift.** Briefs propagate through the polish loop as a system-prompt anchor. Research notes propagate into generate as factual ground truth, never as text to be paraphrased.

## File layout

```
comma/
├── mod.nu          # entry point — re-exports all submodules, defines status/model commands and aliases
├── transform.nu    # tr, rw, sum, proof, tone
├── generate.nu     # draft, expand, title, ideas, ask (all support --notes)
├── analyze.nu      # stats, freq, lix, … + LLM analyzers + report
├── validate.nu     # factcheck, quotes, claims (web_search-enabled)
├── research.nu     # fetch, meta, links, feeds, distill, cite, context
├── iwe.nu          # iwe-find, iwe-tree, iwe-stats, iwe-new, iwe-squash, …
├── feeds.nu        # subscribe, sync, posts, mark-read (blogtato-backed)
├── pipeline.nu     # polish (orchestrates analyze + transform + generate)
├── convert.nu      # to-pdf, to-html, to-docx, to-epub, to-typst, preview, pub
└── publish.nu      # reserved — platform-publishing APIs
```

Each submodule keeps its private helpers (`comma-call`, `comma-input`) local to avoid circular imports across the directory module. The duplication is intentional and small (~25 lines per file).

## Status command

`status` (alias `,?`) prints the current configuration and the full command inventory, grouped by module. Run it whenever you forget what's available.
