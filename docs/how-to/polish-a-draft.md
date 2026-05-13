---
title: "Iteratively polish a draft"
parent: "How-to guides"
nav_order: 4
---

# How to iteratively polish a draft

## Goal

Take a rough draft and run it through the critic loop until it meets quality thresholds — proofread, no accidental repetition, sensible Lix range, optionally fact-checked.

## Basic recipe

```nu
open --raw draft.md | polish > polished.md
```

The defaults run `--level editorial`, which combines:

- Deterministic: `lix` (target 30–50), `repeats` (4-gram or longer, ≥ 2 occurrences)
- LLM: `proof`, `readability`

The loop stops at the first of: no findings, hash convergence, or 4 passes.

## See what is happening

```nu
open --raw draft.md | polish --verbose > polished.md
```

Verbose output goes to stderr (so the polished text on stdout stays pipeable). You will see per-pass findings and a final revision log.

Example:

```
pass 1: 3 finding(s)
  · proof [sev 3]: korrekturfejl fundet
  · repeat [sev 1]: gentaget frase: "we are currently working on" x3
  · lix-too-high [sev 2]: lix 53.2 over loft 50
pass 2: 1 finding(s)
  · repeat [sev 1]: ...
pass 3: clean, stopper

=== revisionslog ===
...
```

## Anchor against drift

Always pass `--brief` for non-trivial polishing — without it, the LLM can slowly rewrite your text into something that no longer serves the original intent:

```nu
open --raw draft.md \
  | polish --brief "blog post about Q3 results for the board" --verbose \
  > polished.md
```

The brief is included in every patch instruction so the model knows what the text is supposed to be doing.

## Levels

```nu
polish --level light       # proof + lix only
polish --level editorial   # default — adds repeats, readability
polish --level publication # adds factcheck + quotes as warnings
```

`light` is fast and cheap, suitable for emails and short drafts.

`editorial` is the default and what most longer drafts need.

`publication` is for things going public. It does *not* auto-fix factual issues — `factcheck` and `quotes` findings are surfaced as warnings on stderr (because they require human judgment) while the rest of the loop still applies fixes.

## Adjust thresholds

If the default Lix range is wrong for your genre, change it:

```nu
# Easier reading: target 25–35 (popular non-fiction range)
polish --lix-min 25 --lix-max 35

# Tolerant of long words: target 35–55
polish --lix-min 35 --lix-max 55
```

Adjust the repeat sensitivity:

```nu
# Catch even 3-word repeats
polish --repeat-min-length 3

# Only flag 6+ word phrases
polish --repeat-min-length 6
```

## Cap iterations

```nu
polish --max-passes 2     # at most 2 passes
polish --max-passes 0     # no critic loop at all — just return input
```

Use `--max-passes 0` when you want `polish`'s resolve-initial logic (e.g. generate from `--brief` if no input) without the loop.

## Generate then polish in one go

If you pass `--brief` without piping any text in, polish first generates a draft from the brief, then polishes it:

```nu
polish --brief "LinkedIn post: we shipped Q3 deliverables" --level light --verbose
```

## Within a longer pipeline

```nu
# Research → draft → polish → publish, all anchored to one brief
let brief = "blog post about espresso for home baristas"
$brief
  | draft --notes espresso-essentials
  | polish --brief $brief --level editorial
  | to-pdf espresso.pdf --title "Espresso essentials"
```

## What `polish` does *not* do

- It does not browse your IWE notes. Use `draft --notes` upstream for grounding.
- It does not regenerate the entire text. Each pass applies targeted patches — three small diffs, not one big rewrite.
- It does not auto-fix factchecking warnings at `--level publication`. Those are flagged for you to read.

## Related

- [Tutorial 02](../tutorials/02-the-research-pipeline.md) — polish in context of the full pipeline
- [reference/pipeline](../reference/pipeline.md) — full flag reference for `polish`
- [Explanation: the critic loop](../explanation/the-critic-loop.md) — why polish patches rather than redrafts
