---
title: "Ground generation in research notes"
parent: "How-to guides"
nav_order: 2
---

# How to ground generation in research notes

## Goal

Have `draft`, `expand`, `ask`, `ideas` or `title` use your IWE notes as factual ground truth instead of letting the LLM invent freely.

## Prerequisites

- An IWE workspace (`iwe init` in some directory)
- One or more notes in it (`iwe new "<Title>" < some-content.md`, or with `-c "<content>"`)
- You are running comma from inside that workspace

## Basic recipe

```nu
"blog post about espresso for home baristas" \
  | draft --notes espresso-essentials
```

`--notes espresso-essentials` tells comma to:

1. Call `iwe retrieve -k espresso-essentials -d 2 -c 1 -f markdown` to pull the note plus 2 levels of children and 1 level of parent context.
2. Cap the result at ~16000 chars (~4000 tokens) so it fits in a prompt.
3. Prepend it to the system prompt as a "research context" block with explicit instructions that the model use it as factual ground truth.

The model gets your research; you get a draft that reflects it.

## Tuning the context

### Adjust hierarchy depth

```nu
"..." | draft --notes espresso-essentials --notes-depth 3
```

`--notes-depth N` controls how many levels of inclusion-link children IWE retrieves. Higher depth = more context, but also slower and more tokens.

### Brief instead of full background

When the note hierarchy is large, the full retrieval may bloat the prompt. Switch shape to `brief`:

```nu
"..." | draft --notes espresso-essentials --notes-shape brief
```

`brief` runs `sum --max 10` over the retrieved markdown — the LLM sees a compressed version. Useful for kicking off creative work where the model only needs the gist.

### Quotes only

```nu
"..." | draft --notes espresso-essentials --notes-shape quotes-only
```

Extracts only blockquote lines (`>`) from the retrieval. Use this when you want the model to riff on specific source quotes without paraphrasing the surrounding analysis.

## Which generate commands take `--notes`

All five:

| Command | When `--notes` helps |
|---|---|
| `draft` | Write a piece grounded in research |
| `expand` | Expand bullets while pulling in source detail |
| `title` | Propose topical titles informed by content |
| `ideas` | Brainstorm with research as inspiration |
| `ask` | Generate questions about a documented topic |

## Composition examples

### Multi-stage with research

```nu
# Distill captured sources into separate notes
fetch <url1> | distill | iwe new "Espresso source 1"
fetch <url2> | distill | iwe new "Espresso source 2"

# (Optionally edit a parent espresso-essentials.md to add inclusion links
# to the two notes above so they're retrieved together.)

# Generate from the essentials parent
"FAQ for first-time espresso users" \
  | ask --notes espresso-essentials --kind faq --count 10
```

### Draft then polish, both grounded

```nu
"blog post about espresso for home baristas" \
  | draft --notes espresso-essentials \
  | polish --brief "blog post about espresso for home baristas" \
           --level editorial
```

The brief is repeated because `polish` uses it as a separate anchor against drift during the critic loop. `polish` itself doesn't read your IWE notes — only `draft` does, but the polish patches still respect the original draft (which already reflects the research).

## Two patterns: LLM synthesis vs. skeleton assembly

`draft --notes` is one of two ways to turn many research notes into one finished piece. They serve different intentions and you should pick deliberately.

### Pattern A — LLM synthesis with `draft --notes`

You give the LLM all the research and a brief. It writes a new article that synthesizes across the notes.

```nu
"blog post for home baristas: what controls espresso extraction" \
  | draft --notes espresso-essentials --notes-depth 2 \
  | polish --brief "blog post for home baristas: what controls espresso extraction"
```

**Pros:** the LLM can rewrite freely, find connections between sources, adapt tone to the brief.

**Cons:** synthesis is opaque — you can't easily tell which note contributed which sentence. Long hierarchies blow the context window. The LLM may overweight one source and ignore others.

**Use when:** you have a clear brief and the research is background context for an original piece.

### Pattern B — Skeleton assembly with `iwe squash`

You author an IWE skeleton document where each section is an inclusion link to a research note. `iwe squash` materializes the skeleton into the final text by inlining all the links.

```nu
# 1. Each source is its own note
fetch <url1> | distill | iwe new "Extraction basics"
fetch <url2> | distill | iwe new "Grind size"
fetch <url3> | distill | iwe new "Temperature"

# 2. Author a skeleton with inclusion links in your editor
#    espresso-article.md:
#
#    # Espresso essentials
#
#    ## Extraction
#    [extraction-basics]
#
#    ## Grind
#    [grind-size]
#
#    ## Temperature
#    [temperature]
#
#    ## Conclusion
#    ...your own prose...

# 3. Squash assembles everything into one document on stdout
iwe squash espresso-article | save -f draft.md

# 4. Continue the comma pipeline
open --raw draft.md \
  | polish --brief "Espresso essentials article" --level editorial \
  | to-pdf out.pdf
```

**Pros:** full control over structure and what goes where. Provenance is preserved — each section transparently came from one note. No LLM call is needed for assembly. Scales to dozens of sources without context-window concerns.

**Cons:** you write the skeleton and any connective tissue by hand. Less suitable when the structure of the final piece is still uncertain.

**Use when:** you know the structure, you have already distilled each source carefully, and you want the final piece to read as *your* composition of *your* research rather than an LLM rewrite.

### Mixing the two

The patterns compose: assemble with `iwe squash`, then run sections through `rw` or `polish` to smooth them. Or use `draft --notes` for individual sections that need synthesis, then weave them together by hand. Comma's commands are pipe-friendly enough that you can mix freely.

See [reference/research: `iwe squash` and `iwe inline`](../reference/research.md#iwe-squash-and-iwe-inline-assembly-primitives) for the assembly details.

## When *not* to use `--notes`

- For pure creative writing where you don't want the model anchored to anything specific.
- When the note is too large — switch to `--notes-shape brief` instead of removing `--notes`.
- When you are translating or proofreading — use `transform.nu` commands which don't accept `--notes` because they don't need it.
- When you have already written all the prose yourself and just want to *assemble* it — use `iwe squash` (pattern B above), not `draft --notes`.

## Related

- [Tutorial 02](../tutorials/02-the-research-pipeline.md) — full pipeline example
- [`context`](../reference/research.md#context) — the underlying retrieve+shape command, useful for inspecting what your generate calls will see
- [`iwe squash` and `iwe inline`](../reference/research.md#iwe-squash-and-iwe-inline-assembly-primitives) — assembly primitives for skeleton-based composition
- [Explanation: why IWE](../explanation/why-iwe.md) — why notes live in IWE and not in comma's own store
