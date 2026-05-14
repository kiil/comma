---
title: "02 — The research-to-publish pipeline"
parent: "Tutorials"
nav_order: 2
---

# Tutorial 02 — The research-to-publish pipeline

This tutorial walks you through comma's full pipeline: capture material from the web, distill it into a structured note, generate a draft grounded in that research, polish the draft iteratively, and publish it as a PDF.

Allow 30 minutes. This is the tutorial that shows you *why* comma is organized the way it is.

## What you will learn

1. How to capture a web article as clean markdown with `fetch`
2. How to distill raw material into a structured study note
3. How to use IWE as a knowledge graph for notes
4. How `--notes <key>` grounds an LLM draft in your research
5. How `polish` iteratively refines a draft
6. How to render the final text to PDF

## Before you start

You need the basic setup from [Tutorial 01](01-getting-started.md), plus:

- **reader** — `go install github.com/mrusme/reader@latest`
- **iwe** — see https://iwe.md for install
- **pandoc** and **typst** — `brew install pandoc typst` on macOS

Confirm everything is on `$PATH`:

```nu
which reader iwe pandoc typst
```

Create a working IWE workspace for this tutorial:

```nu
mkdir ~/comma-tutorial
cd ~/comma-tutorial
iwe init
```

## Step 1 — Capture a source

We will use Wikipedia's article on coffee extraction as our source material. The `fetch` command runs the URL through Mozilla's Readability algorithm (via the `reader` binary) and returns clean markdown:

```nu
fetch "https://en.wikipedia.org/wiki/Coffee_extraction"
```

You will see the article body printed — no navigation, no sidebar, no edit links. Just the prose, headings and citation markers.

Capture it as an IWE note:

```nu
fetch "https://en.wikipedia.org/wiki/Coffee_extraction" | save -f raw-extraction.md
iwe new "Raw extraction" < raw-extraction.md
```

We saved to a file first so you can see what was fetched. In a real workflow you could pipe directly: `fetch <url> | iwe new "Raw extraction"`. The note slug becomes `raw-extraction` (lowercased and slugified from the title).

## Step 2 — Distill the raw material

Raw web pages are wordy. The `distill` command runs the markdown through an LLM that extracts:

- **Claims** — what the source asserts as fact
- **Quotes** — verbatim passages worth keeping
- **Open questions** — gaps the source itself implies
- **Keywords** — topical tags

```nu
open --raw raw-extraction.md | distill | save -f extraction-essentials.md
iwe new "Extraction essentials" < extraction-essentials.md
```

Look at the distilled note:

```nu
open --raw extraction-essentials.md
```

You should see clear sections under `## Claims`, `## Quotes`, `## Open questions`, `## Keywords`. This is research-grade material — concise, structured, easier for both you and an LLM to use as ground truth.

## Step 3 — Generate a draft grounded in research

Now we ask `draft` to write something using our extraction note as factual ground truth. The `--notes` flag tells comma to retrieve the note from IWE, shape it into a context block, and prepend it to the system prompt:

```nu
"Blog post for home baristas: what controls espresso extraction, and how to tune it. Target 250 words, friendly tone." \
  | draft --notes extraction-essentials \
  | save -f draft.md
```

Open `draft.md`. Notice that the post reflects specific facts from the source — not generic LLM coffee blather. That is what `--notes` does: it grounds the model in your research instead of letting it hallucinate.

## Step 4 — Polish the draft

A first-pass LLM draft is rarely publication-ready. The `polish` command runs an iterative critic loop:

- Each pass runs deterministic critics (`lix` for readability, `repeats` for accidental phrase duplication) and LLM critics (`proof` for spelling/grammar, `readability` for accessibility).
- Each finding becomes a targeted fix — a small patch, not a full redraft.
- The loop stops when there are no findings, when the text stops changing (hash convergence), or when the pass limit is hit.

Run it with `--verbose` so you can see what happens:

```nu
open --raw draft.md \
  | polish --level editorial \
    --brief "Blog post for home baristas: what controls espresso extraction" \
    --verbose \
  > polished.md
```

You'll see something like:

```
pass 1: 2 finding(s)
  · proof [sev 3]: korrekturfejl fundet
  · repeat [sev 1]: gentaget frase: "...long extraction times..." x2
pass 2: 1 finding(s)
  · repeat [sev 1]: ...
pass 3: clean, stopper

=== revisionslog ===
...
```

The `--brief` flag anchors the loop against drift — every patch is told what the original intent was so the LLM doesn't slowly rewrite the post into something different.

Open `polished.md` and compare to `draft.md`. The polish is real but small: corrected punctuation, varied phrasing where things repeated, sentences shortened if Lix was too high.

## Step 5 — Render to PDF

Finally, publish:

```nu
open --raw polished.md \
  | to-pdf espresso.pdf \
    --title "Espresso extraction for home baristas" \
    --author "Your Name"
```

The PDF is rendered through pandoc with `typst` as the engine — faster and prettier than LaTeX, and you don't need a LaTeX install. Open the result:

```nu
^open espresso.pdf
```

## Reflection

You just used five of the six comma modules:

```
research  → fetch, distill
generate  → draft (--notes)
analyze   → (used inside polish: lix, repeats, proof, readability)
transform → (used inside polish: rw to apply patches)
publish   → to-pdf
```

The flow has a clear narrative: capture material, distill it, generate from a grounded brief, refine through critique, render to a target format. Each module does one job. The pipeline is the value.

## What's next

- Read [Explanation: the critic loop](../explanation/the-critic-loop.md) to understand why `polish` patches rather than redrafts.
- Read [Explanation: why IWE](../explanation/why-iwe.md) to understand why comma delegates note persistence rather than owning it.
- For specific tasks (proofreading a Danish document, fact-checking an article, etc.), see the [how-to guides](../how-to/).
