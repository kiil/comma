---
title: "iwe"
parent: "Reference"
nav_order: 6
---

# Reference: iwe

Wrappers around the [IWE](https://iwe.md) CLI that reshape its output into nu records/tables and accept piped input where it makes sense. Where comma's [research](research.md) module already wraps an iwe operation with a specific intent (`context` over `iwe retrieve`, `bibliography` over the inclusion-link hierarchy), those stay there. `iwe.nu` is the generic-wrapper layer.

> **Naming:** every command is prefixed `iwe-`. The bare names (`stats`, `extract`, `tree`, etc.) would collide with existing comma commands; the prefix also makes it obvious which operations talk to the iwe binary.

**Dependency:** `iwe` on PATH. All commands must be run from inside an IWE workspace (a directory with a `.iwe/` folder).

> **Starting point:** a ready-to-use `.iwe/config.toml` example for the comma research flow lives at [`examples/iwe-config.toml`](https://github.com/kiil/comma/blob/main/examples/iwe-config.toml). It sets up a `research` template (puts notes under `research/<slug>.md`) plus `today` and `research-inbox` attach actions so capture can chain into a daily log and a rolling inbox.

## Capture

### `iwe-init`

Initialize the current directory as an IWE workspace.

```
iwe-init
```

### `iwe-new`

Create a new document. Content can come from the pipe, the `--content` flag, or stdin redirection. IWE slugifies the title for the filename.

```
iwe-new <title> [--content <text>] [--template <name>]
```

| Flag | What |
|---|---|
| `title` | document title; slugified into the filename |
| `-c, --content` | inline content (alternative to piping) |
| `-t, --template` | template name from `.iwe/config.toml` |

**Examples:**

```nu
"Body of the note" | iwe-new "My note title"
iwe-new "My note title" --content "..."
open --raw draft.md | iwe-new "Imported draft"
fetch <url> | distill | iwe-new "Espresso essentials"
```

## Search and inspection

### `iwe-find`

Search documents — fuzzy match on title and key, optionally narrowed by filter flags. Returns a table.

```
iwe-find [query] [--limit <n>] [--filter <yaml>]
         [--key <k>] [--includes <k>] [--included-by <k>]
         [--references <k>] [--referenced-by <k>]
```

**Examples:**

```nu
iwe-find espresso
iwe-find --limit 5
iwe-find --filter "status: draft"
iwe-find --included-by espresso-essentials
```

### `iwe-count`

Count documents matching a filter — much faster than `iwe-find | length` on large graphs.

```
iwe-count [--filter <yaml>] [--key <k>] [--included-by <k>] [--references <k>]
```

Returns an integer.

### `iwe-tree`

Display the document hierarchy as a structured tree. Default format returns nested records (json); use `--format markdown` for the human view, `--format keys` for a flat list of keys.

```
iwe-tree [--depth <n>] [--key <k>] [--filter <yaml>] [--format <fmt>]
```

| Flag | Default | What |
|---|---|---|
| `-d, --depth` | 4 | maximum nesting depth |
| `-k, --key` | — | start tree from this document |
| `--filter` | — | inline YAML filter |
| `--format` | `json` | `json`, `yaml`, `markdown`, `keys` |

### `iwe-stats`

Workspace statistics — document count, references, top documents by sections, network analytics. Returns a record.

```
iwe-stats [--key <k>]
```

**Examples:**

```nu
iwe-stats | get totalDocuments
iwe-stats | get topDocsBySections | first 5
iwe-stats --key README          # stats for a single document
```

## Retrieval and assembly

### `iwe-retrieve`

Raw document retrieval. For the prompt-shaped variant used by `--notes` flags in generate commands, see [research.context](research.md#context).

```
iwe-retrieve <key> [--depth <n>] [--context <n>] [--format <fmt>]
                   [--links] [--backlinks]
```

| Flag | Default | What |
|---|---|---|
| `key` | required | document key |
| `-d, --depth` | 1 | levels of children to follow |
| `-c, --context` | 1 | levels of parent context to include |
| `-f, --format` | `markdown` | `markdown`, `keys`, `json`, `yaml` |
| `-l, --links` | off | also include inline-referenced documents |
| `-b, --backlinks` | off | also include incoming references |

### `iwe-squash`

Squash a document tree into one consolidated markdown document. Non-destructive — source files are not modified. The right tool when you have written a skeleton with inclusion links and want to render the assembled draft.

```
iwe-squash <key> [--depth <n>]
```

**Examples:**

```nu
iwe-squash espresso-article | save -f draft.md
iwe-squash espresso-article | polish --brief "espresso article" | to-pdf out.pdf
```

See [the skeleton-assembly pattern](../how-to/ground-generation-in-research.md#pattern-b---skeleton-assembly-with-iwe-squash) for the full multi-source workflow.

### `iwe-attach`

Attach a source document as a block reference under one or more configured attach actions (see `.iwe/config.toml`). Without `--to`, lists the configured actions.

```
iwe-attach --list
iwe-attach -k <source-key> --to <action> [--dry-run]
```

**Examples:**

```nu
iwe-attach --list                                  # show configured actions
iwe-attach -k coffee-deep-dive --to daily
iwe-attach -k coffee-deep-dive --to daily --dry-run
```

## Refactoring

### `iwe-rename`

Rename a document. All inclusion links and references across the workspace are updated automatically.

```
iwe-rename <old> <new>
```

### `iwe-delete`

Delete a document and clean up references to it.

```
iwe-delete <key> [--dry-run]
```

### `iwe-normalize`

Normalize all markdown files in the workspace — consistent header levels, link formats, frontmatter formatting. Useful as a periodic cleanup or before committing to git.

```
iwe-normalize [--dry-run]
```

## Compositions

These wrappers compose with the rest of comma. A few patterns worth noting:

```nu
# Capture an article straight into IWE
fetch <url> | distill | iwe-new "Espresso essentials"

# List notes that include a given parent and act on each
iwe-find --included-by espresso-essentials
    | get key
    | each {|k| iwe-retrieve $k | proof}

# Workspace-wide stats fed into analysis
iwe-stats | get topDocsBySections | first 10 | select title sections lines

# Pre-publish: list all draft-status notes
iwe-find --filter "status: draft"

# Build a skeleton draft and render
"# My article

[section-a]

[section-b]
" | iwe-new "Article draft"
iwe-squash article-draft | polish --brief "my article" | to-pdf out.pdf
```
