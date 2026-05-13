---
title: "The critic loop"
parent: "Explanation"
nav_order: 2
---

# The critic loop

`polish` is the orchestration command — it runs the analyze and transform modules in a loop. This page explains the design choices that make it work and the failure modes it avoids.

## The naive approach

A first instinct for "polish my draft" is to ask the LLM to do it:

```
"Here is my draft. Make it better."
```

This fails in three ways:

1. **Unbounded changes.** "Better" is not defined. The model rewrites things you didn't want rewritten. Tone shifts. Facts smooth away.
2. **No stopping criterion.** Run it twice and you get a different "better." Run it ten times and the text bears no resemblance to your draft.
3. **No accountability.** You cannot tell *why* it changed each thing or whether the changes were justified.

`polish` is built specifically to avoid these three failure modes.

## The structure: critique → patch → check

Each pass of `polish` does three things:

1. **Critique** — run deterministic checks (`lix`, `repeats`) plus LLM critics (`proof`, `readability`, optionally `factcheck`/`quotes`). Each surfaces a list of *findings* with kind, severity, description, and a targeted fix instruction.

2. **Patch** — for each finding, apply a small fix. Not a rewrite of the whole text. The fix is either an automatic replacement (proofreading, which already produces a corrected version directly) or a targeted `rw` call with the finding's instruction.

3. **Check** — has the text changed? If not, the loop has converged. If yes, run another pass.

The loop stops on the first of: no findings, hash convergence, or `--max-passes` reached.

## Why patch instead of redraft

The first design choice — and the most important one — is that each fix is a small, targeted operation rather than a rewrite of the whole document.

What you lose with patching:

- A patch sometimes leaves the surrounding text awkward. A repeated phrase fix may produce a slightly disconnected paragraph.
- The model has less context than it would with a full rewrite, so individual fixes are sometimes shallow.

What you gain:

- Sentences and phrases you liked stay. Specific facts stay. The voice stays.
- Each pass produces a small, comprehensible diff.
- The loop converges quickly because each pass changes less.

The trade is favourable in practice. Three small patches that each preserve 99% of the text are better than one rewrite that preserves 80%.

## Why deterministic critics first

The critique step is split deliberately:

- **Deterministic critics** (`lix`, `repeats`) measure objective properties. They have hard thresholds. They cannot ask for "more polish" in some vague sense.
- **LLM critics** (`proof`, `readability`) handle things that need judgment.

The deterministic critics provide a stop condition. If only LLM critics ran, the loop would never end — LLMs are good at finding *something* to criticize, especially in their own outputs. You would polish until the model said "OK" — which is whenever it feels like it.

This is the practical reason `polish` runs all the deterministic critics on every pass even though they are conceptually cheaper.

## Anchoring against drift

Even with patching, drift is possible. Each `rw` call can subtly shift the document. After several passes, the cumulative shift can be noticeable.

`--brief` defends against this. The brief is appended to every patch instruction:

```
Original brief (preserve the intent faithfully): <your brief>
```

The model sees the original intent on every fix. A patch that would drift away from the brief is less likely to happen because the model has a continuous reminder of what the text is supposed to be doing.

For non-trivial polishing, always pass `--brief`. Without it, the loop becomes more cautious by default — but with it, the loop is *purposeful*.

## Convergence: hash check

Even without findings remaining, sometimes the text oscillates: pass 2 changes A, pass 3 changes A back, pass 4 changes A again. To detect this:

```
prev_hash = sha256 of draft before patches
new_hash  = sha256 of draft after patches
if prev_hash == new_hash: stop
```

This is the third stop condition, after "no findings" and "max passes." In practice, it catches `proof`-vs-`repeats` interactions — `proof` reverts something `repeats` changed, or vice versa — and stops the loop before they fight indefinitely.

## Levels: cost vs. coverage

`polish` has three preset profiles:

| Level | Critics | Cost | Use case |
|---|---|---|---|
| `light` | proof + lix + repeats | 1 LLM call per pass | Emails, short pieces |
| `editorial` | + readability | 2 LLM calls per pass | Default for longer drafts |
| `publication` | + factcheck + quotes (as warnings) | 4+ LLM calls per pass, with `web_search` | Pieces going public |

The publication-level extras (`factcheck`, `quotes`) deliberately do not auto-fix. They produce warnings on stderr because their findings need human judgment — a factcheck failure could be a factual error, a contested claim, or a model misunderstanding. Auto-rewriting that would be irresponsible.

## What `polish` is not

A few things `polish` deliberately does *not* do:

- **It does not read your IWE notes.** Use `draft --notes <key>` upstream to ground the initial draft; polish trusts that grounding and works on the text in front of it.
- **It does not run `factcheck` and `quotes` as auto-fixes.** See above — these are advisory at publication level.
- **It does not parallelize critics across passes.** Each pass is sequential because patches can interact. A future optimization could parallelize within a pass if findings are independent, but this is not currently a bottleneck.
- **It does not store revision history.** That's git's job. Save your draft to git before polishing if you want a baseline.

## When `polish` is the wrong tool

- **For a clean text that needs creative reshaping** — use `rw` with a freeform instruction directly. Polish is for correctness and tightening, not creative rewrites.
- **For a translation** — use `tr`. The polish loop runs in the source language only.
- **For LLM-only judgement calls** without deterministic anchors — use the individual LLM critics directly (`proof`, `readability`) and decide for yourself.

## In one sentence

`polish` is a bounded loop of deterministic-anchored, LLM-driven, patch-not-redraft refinements with an anti-drift anchor — designed specifically to avoid the failure modes of "ask the model to improve it."
