---
title: "Design principles"
parent: "Explanation"
nav_order: 1
---

# Design principles

Six rules govern how commands in comma are designed. They are not formal — they are the heuristics we reach for when adding a new command or evaluating an existing one. Together they explain why the module ended up shaped the way it is.

## 1. Stateless commands, optional stateful filesystem

Every command is `text in → text out`. No invocation depends on what happened previously; the model has no memory across calls.

The trade-off is that you sometimes want continuity — research notes that accumulate, drafts that evolve. Comma's answer is: persistence lives in the filesystem (as markdown), not inside comma. The user owns their IWE workspace. Comma rents access to it via the `context` command and the `--notes` flag.

Why this trade-off is right:

- Pipelines stay predictable. The same input always produces the same output (modulo LLM randomness, which we cannot control).
- Debugging is local. If a draft is wrong, you do not have to inspect a hidden state to know why.
- Tooling stays simple. No "comma reset" or "comma clear context" commands; no cache invalidation.

## 2. Pipe-first

Pipeline input is the primary input. Positional arguments exist only as a convenience for short inline strings during interactive sessions.

Output is plain text on stdout. No markdown wrappers, no "Here is your translation:" preambles, no JSON envelopes, no trailing whitespace. The `PURITY_RULE` constant in every LLM-calling file enforces this with explicit instructions to the model.

The result: every comma command composes with every other comma command, and with every standard nushell command (`save`, `lines`, `where`, `each`, etc.) without glue code.

## 3. Determinism where possible

Word frequency, n-grams, Lix scoring, stopword filtering, Jaccard similarity, regex extraction, sentence splitting — all of this is pure nushell. It runs offline, in milliseconds, and produces the same result every time.

LLMs are reserved for tasks where they genuinely add value: translation, classification under ambiguity, register shifts, semantic summarization, fact-checking against the open web. Anything that *could* be done deterministically *should* be.

This has practical consequences:

- `polish` uses deterministic critics (`lix`, `repeats`) as its stop condition, with LLM critics layered on top. If we relied only on LLM critics, the loop would never stop — they always find *something*.
- `report` defaults to including everything (deterministic + LLM) but offers `--no-llm` for the cost-conscious or offline workflow.
- The `analyze` module is explicitly split in its reference doc and `status` output: deterministic commands are listed separately from LLM commands.

See [Deterministic vs. LLM](deterministic-vs-llm.md) for the longer discussion.

## 4. Minimal magic — wrap thinly

Where a command depends on an external tool — `reader`, `pandoc`, `typst`, `iwe`, `http browse` — the wrapper is as thin as possible. We expose just enough surface to make the pipeline ergonomic, and we let the underlying tool's flags pass through where it makes sense.

Examples:

- `context <key>` passes `-d` and `-c` directly to `iwe retrieve` because IWE's flag names are already good.
- `to-pdf` exposes `--engine` so the user can swap typst for xelatex without comma needing to know anything about LaTeX.
- `fetch --js` delegates JS rendering to `nu_plugin_browse`, then pipes raw HTML to `reader` for the actual extraction.

We deliberately do *not* try to be a higher abstraction. If you outgrow comma, you should be able to reach the underlying tools without unlearning anything.

## 5. Patch, don't redraft

The `polish` critic loop applies targeted fixes per finding rather than regenerating the entire text. If `proof` flags three corrections, three small fixes happen — not one rewrite of the whole document.

Why: a full rewrite under LLM control drifts. Sentences you liked get reworded. Specific facts get smoothed away. Tone shifts. After two passes, the text no longer feels like yours.

Patching keeps the parts that worked. The `--brief` flag carries the original intent into every patch instruction as an anti-drift anchor, so even the patches stay aligned with what the text is supposed to do.

See [The critic loop](the-critic-loop.md) for the longer discussion of patch-vs-redraft and convergence.

## 6. Anchor against drift

LLM workflows have a quiet failure mode: each step seems sensible in isolation, but the cumulative effect is that the output has drifted away from the original intent.

Comma's defences:

- **Briefs propagate.** When you start with `--brief`, it gets appended to every downstream `rw` call inside `polish`. The model sees the original intent on every patch.
- **Research grounds.** When you use `--notes`, the retrieved markdown is prepended as factual ground truth. The model is told explicitly: do not invent beyond these notes.
- **Determinism stops drift.** Deterministic critics give the polish loop a fixed target. Lix doesn't move because the LLM feels like it; either the score is in band or it isn't.

Drift is the failure mode no one notices because each step "made sense at the time." Anchors make sure we always know what the original sense was.

## How these interact

The rules are mutually reinforcing. Pipe-first plus stateless means commands are composable. Composable plus thin wrappers means the user can replace any link in the chain. Determinism plus anchor-against-drift means iteration converges. Patch-not-redraft plus stateless means you can always start over with the previous version cleanly.

When in doubt, the order to apply them is: anchor → determine → patch. Start with the brief, run the cheap deterministic checks, apply small fixes. Reach for LLMs only when the deterministic answer is unavailable.
