---
title: "validate"
parent: "Reference"
nav_order: 4
---

# Reference: validate

Verification against reality. Where [analyze](analyze.md) inspects text as text (statistics, classification, readability), validate asks whether what the text says is *true*. That requires lookups, sources, and stronger reasoning than the other LLM-backed commands.

The validate commands use `$env.COMMA_VALIDATE_CFG` (default: `gemini-3-pro-preview` with `web_search,nu` tools) instead of the main `COMMA_CFG`. This is intentional — without `web_search`, `factcheck` and `quotes` would simply hallucinate citations. See [configuration](configuration.md).

## `factcheck`

Verify factual claims via `web_search`.

```
factcheck [--strict] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-s, --strict` | off | Flag every claim including small numerical/chronological inaccuracies |

Output format: one line per claim, `[<verdict>] <claim> — <evidence> (<source>)`. Verdicts: TRUE, FALSE, MISLEADING, UNVERIFIABLE. Order: most consequential errors first.

If no errors: returns exactly `OK — no errors found`.

**Example:**

```nu
"Denmark has 12 million inhabitants" | factcheck
open --raw article.md | factcheck --strict
```

**Alias:** `,fc`

## `quotes`

Verify quotation wording and attribution via `web_search`.

```
quotes [...text]
```

For each quoted passage in the text, the model checks:

1. Is the wording accurate?
2. Is the attribution correct?
3. Is the context appropriate (not a misattributed paraphrase, not stripped of meaning)?

Output: one block per quote with fields `quote`, `attribution`, `verdict` (VERIFIED, MISQUOTED, MISATTRIBUTED, FABRICATED, UNVERIFIABLE), `correction`, `source`.

If no quotes are found: returns exactly `no quotes found`.

**Example:**

```nu
"Som Einstein sagde: 'Gud spiller ikke terninger'" | quotes
open --raw speech.md | quotes
```

**Alias:** `,qu`

## `claims`

Extract distinct claims from a text. Does not verify them — useful as a preprocessing step before `factcheck`, or as input for debate prep / analysis.

```
claims [...text]
```

Output: one claim per line, rephrased as a standalone declarative sentence so it can be evaluated out of context.

**Example:**

```nu
open --raw essay.md | claims
open --raw essay.md | claims | factcheck    # decoupled two-step verification
```

This command does not strictly need tools, but uses the same `COMMA_VALIDATE_CFG` for consistency with `factcheck` and `quotes`.

**Alias:** `,cm`

## How `polish --level publication` uses these

When `polish` runs at `--level publication`, both `factcheck` and `quotes` are invoked once at each pass and surfaced as warnings on stderr. They are *not* auto-fixed — a factcheck failure could be a real error, a contested claim, or a model misunderstanding, and only you can decide which. See [pipeline](pipeline.md).
