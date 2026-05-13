---
title: "pipeline"
parent: "Reference"
nav_order: 5
---

# Reference: pipeline

The orchestration module. Currently exposes one command: `polish`.

## `polish`

Iterative critic loop. Optionally generates a draft, runs deterministic + LLM critics, applies targeted patches per finding, repeats until convergence.

```
polish [--level <string>] [--max-passes <int>]
       [--lix-min <int>] [--lix-max <int>] [--repeat-min-length <int>]
       [--brief <string>] [--verbose] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-L, --level` | `editorial` | One of `light`, `editorial`, `publication` |
| `--max-passes` | 4 | Hard cap on iterations |
| `--lix-min` | 30 | Lower Lix threshold (below = "too monotone") |
| `--lix-max` | 50 | Upper Lix threshold (above = "too heavy") |
| `--repeat-min-length` | 4 | Flag n-grams of this length that repeat |
| `--brief` | — | Original brief — used as anti-drift anchor on each patch instruction |
| `-v, --verbose` | off | Log each pass and revision log to stderr |
| `...text` | — | Text inline (otherwise via pipe) |

**Input resolution order:**

1. `...text` positional args (joined with spaces)
2. Pipe input (string or list<string>)
3. `--brief` argument — generates an initial draft via `generate.draft`, then polishes it

If none of the three is provided, errors.

**Pipe input must be a string** (or list of strings). Markdown AST tables (from `open file.md` without `--raw`) are rejected with a clear error.

## Critic levels

### `light`

- Deterministic: `lix`, `repeats`
- LLM: `proof`

Fast and cheap. Suitable for emails, short drafts.

### `editorial` (default)

- Everything in `light`
- LLM: `readability` (triggers a finding only if level is `hard` or `very hard`)

Recommended default for longer drafts.

### `publication`

- Everything in `editorial`
- LLM (warnings, not auto-fixes): `factcheck`, `quotes`

The warning kind is reported on stderr and requires human review. The loop still applies the editorial-level fixes.

## How findings become patches

Each finding has a `kind`, `severity`, `description` and `instruction`. The `apply-fix` step routes by kind:

- `proof` — special case; the finding includes a `replacement` field, the entire text is replaced.
- All others — generic patch via `rw <instruction>`. If `--brief` is set, the brief is appended to the rw prompt as an anti-drift anchor.

## Stop conditions

The loop breaks on the first of:

1. **No findings** — pass completes with zero findings. Logged as "clean".
2. **Hash convergence** — `sha256` of the draft unchanged after applying all fixes in a pass.
3. **Max passes** — pass count equals `--max-passes`.

## Output

- **stdout**: the final polished text (or the resolved initial text if `--max-passes 0`).
- **stderr** (only with `--verbose`):
  - Per-pass finding summaries
  - A revision log table
  - Warnings (at `--level publication`)

This split means polish can be piped without contaminating downstream commands:

```nu
open --raw draft.md | polish --verbose | to-pdf out.pdf
```

## Example

```nu
open --raw draft.md \
  | polish --level editorial \
    --brief "blog post about espresso for home baristas" \
    --lix-min 30 --lix-max 50 \
    --max-passes 4 \
    --verbose \
  > polished.md
```

**Alias:** `,po`

## Dependencies

`polish` imports from `transform.nu` (rw, proof), `analyze.nu` (lix, repeats, readability, factcheck, quotes) and `generate.nu` (draft, for `--brief`-only invocations). All imports happen at module load — no runtime cost.

See also: [How to polish a draft](../how-to/polish-a-draft.md) and [Explanation: the critic loop](../explanation/the-critic-loop.md).
