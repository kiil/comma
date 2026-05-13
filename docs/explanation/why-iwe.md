---
title: "Why IWE for note persistence"
parent: "Explanation"
nav_order: 4
---

# Why IWE for note persistence

When designing `research.nu`, the obvious instinct was: comma owns a notebook. A directory of markdown files in `$COMMA_NOTEBOOK`, with frontmatter conventions and helper commands for capture/search/retrieve.

This page explains why we did not do that, and why comma uses [IWE](https://iwe.md) for persistence instead.

## The instinct was wrong

A first sketch of `research.nu` had commands like:

```
note <title>       — pipe text, save as a note
fetch <url>        — capture URL as a note with source frontmatter
clip               — pbpaste → note
notes              — list notes
notes-find <query> — grep across notes
notes-show <id>    — read one
```

This would have worked. It's familiar. It's the shape every personal-knowledge-management tool ends up with.

The problem: I'd be building a knowledge graph in 200 lines of nushell to compete with tools that have been doing this for years. And the parts I'd skip (semantic search, link integrity, frontmatter querying, refactoring across notes) are the parts that actually matter once a notebook grows past 50 files.

## What IWE provides

IWE is a knowledge-graph system over plain markdown. From comma's perspective the relevant features are:

- **Plain markdown files in a directory.** No proprietary format. Git-versionable.
- **Inclusion links.** A link on its own line means "this note includes that note as a subtopic." This builds the hierarchy.
- **Polyhierarchy.** A note can appear under multiple parents. Cross-cutting topics work naturally.
- **`iwe retrieve <key>`.** Pulls a note plus its children (depth) plus its parents (context). This is the assembly we need for LLM context blocks.
- **Frontmatter query language.** Filter on metadata, tags, status.
- **LSP integration.** Editor-native go-to-definition, rename, find-references.
- **CLI for everything.** Each editor action is also a command. `iwe-attach`, `iwe-extract`, `iwe-inline`, `iwe-rename` etc. all scriptable.

The retrieval primitive — `iwe retrieve` with depth and context flags — is the single feature that pushed the decision. Building the equivalent in comma would have been weeks of work, and the result would still not be as good.

## What comma adds on top

Once we accept IWE as the persistence layer, `research.nu` becomes much thinner. Its job is the parts IWE doesn't do:

| Capability | Owner |
|---|---|
| Persistence (filesystem layout, frontmatter) | IWE |
| Hierarchy via inclusion links | IWE |
| Retrieval with context assembly | IWE |
| Refactoring (rename, extract, inline) | IWE |
| Search and filtering | IWE |
| HTTP capture (`fetch`) | comma |
| Content extraction (Readability) | comma (delegates to `reader`) |
| LLM distillation (raw → structured note) | comma |
| Topic-scoped quote extraction | comma |
| Shaping IWE retrieval for LLM prompts | comma |
| Bridge into `generate` via `--notes` | comma |

The split is clean. Comma's four research commands (`fetch`, `distill`, `cite`, `context`) are each something IWE legitimately doesn't do — capturing from the web, applying LLMs, and shaping retrieval for prompts.

## A small but important consequence: capture is templated

Capture (clip, daily notes, inbox patterns) lives in `.iwe/config.toml` as templates. Comma deliberately does not provide `note`, `clip` or template handling. The reasoning:

- IWE's `attach` action with `key_template` and `document_template` already covers the common capture patterns.
- A user's preferred capture conventions are personal. Codifying them in comma would force a style on everyone.
- The `iwe attach` command can be invoked from a pipe: `pbpaste | iwe attach <key>` does what a comma `clip` would have done, without comma needing to know.

So comma's contribution to capture is just `fetch`. Everything else flows through `iwe`.

## The `context` command is the only bridge

The `--notes` flag on generate commands all go through `research.context`, which is the *only* place in comma that calls `iwe retrieve`. This is intentional:

- One bridge means one place to fix things when IWE's API changes.
- Other commands stay IWE-agnostic — `fetch`, `distill`, `cite` work without an IWE workspace.
- The bridge's surface is minimal: a key, a depth, a parent-context, a max-char cap, and a shape selector.

If a user does not have IWE installed at all, everything else in comma still works. Only `context` and `--notes` fail, and they fail cleanly with a `require iwe` error.

## What we give up by choosing IWE

The trade is real. Adopting IWE means:

- Users who want to use research have to install IWE.
- Users who want a different persistence layer (Obsidian, Logseq, plain folder of markdown without IWE's conventions) cannot use `--notes`.
- We are bound to IWE's frontmatter conventions and inclusion-link syntax.

Each of these is acceptable in context:

- IWE is installable in one `go install` or `cargo install` command. Lower friction than configuring a personal notebook setup.
- For other layers, users can write their own `context` replacement. The `--notes` flag calls `research.context`, which is replaceable.
- IWE's conventions are minimal and pure markdown. Frontmatter is YAML, links are wikilinks. Not lock-in by any reasonable standard.

## The principle this illustrates

Comma is small because it picks well-chosen dependencies and wraps them thinly. `reader`, `pandoc`, `typst`, `iwe`, `yoke` are each the best-in-class tool for their job. The wrappers add ergonomics (pipe-friendliness, sensible defaults, the comma vocabulary) without trying to replace what they wrap.

When in doubt: prefer to wrap an established tool over building a clone.
