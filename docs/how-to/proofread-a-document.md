---
title: "Proofread a document"
parent: "How-to guides"
nav_order: 1
---

# How to proofread a document

## Goal

Correct spelling, grammar and punctuation in a document while preserving the author's voice.

## Basic recipe

```nu
open --raw draft.md | proof | save -f draft.md
```

This overwrites `draft.md` in place with the corrected version. The corrections are conservative — only mechanical errors are fixed; style and word choice are left alone.

## Variations

### Strict mode — also fix awkward phrasing

```nu
open --raw draft.md | proof --strict | save -f draft.md
```

`--strict` additionally rewrites clunky word order and unclear constructions. Use this when proofreading your own first drafts, not for editing someone else's voice.

### Diff-first review

If you want to see what would change before overwriting:

```nu
open --raw draft.md | proof | save -f draft.proofed.md
diff draft.md draft.proofed.md
```

Then merge manually if you disagree with any change.

### Per-paragraph proofreading

For long documents, run paragraph-by-paragraph so the model has tight context and you can review smaller diffs:

```nu
open --raw draft.md
  | paragraphs
  | each {|p| $p | proof}
  | str join "\n\n"
  | save -f draft.proofed.md
```

`paragraphs` is from `analyze.nu` — it splits text on blank lines.

### Within a polish loop

`proof` is one of the critics that `polish` runs automatically. If you are already polishing a draft, you do not need a separate proof step:

```nu
open --raw draft.md | polish --level light > polished.md
```

`--level light` runs only `proof` plus the Lix readability check.

## Language matters

`proof` matches the source language. A Danish text gets Danish-rule corrections (compound nouns, comma rules); an English text gets English. You do not need to tell it the language — the LLM detects it.

## What `proof` does *not* do

- It does not change word choice or sentence structure (unless `--strict`).
- It does not adjust register or tone — use `tone` for that.
- It does not translate.
- It does not verify facts — use `factcheck` for that.

## Related

- [`tone`](../reference/transform.md#tone) for register/style shifts
- [`rw`](../reference/transform.md#rw) for freeform rewriting under your own instruction
- [`polish`](../reference/pipeline.md) for the full critic loop
