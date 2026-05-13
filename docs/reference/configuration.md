---
title: "configuration"
parent: "Reference"
nav_order: 7
---

# Reference: configuration

Comma is configured via environment variables and the `model` command. There is no config file.

## Environment variables

### `$env.COMMA_CFG`

Used by `transform`, `generate`, `research`, and `pipeline` (for its LLM critics).

| Field | Default | What |
|---|---|---|
| `provider` | `gemini` | One of `anthropic`, `openai`, `gemini`, `openrouter`, `ollama` |
| `model` | `gemini-3.1-flash-lite-preview` | Provider-specific model ID |
| `tools` | `none` | One of `all`, `code`, `web_search`, `none`, or comma-separated subset |

Set it:

```nu
$env.COMMA_CFG = {provider: openai, model: gpt-4o, tools: none}
```

### `$env.COMMA_ANALYZE_CFG`

Used by LLM commands in `analyze` (detect, sentiment, keywords, entities, readability, classify, factcheck, quotes, claims). Deliberately separated from `COMMA_CFG` so that `factcheck` and `quotes` can use `web_search` without forcing that on every transform.

| Field | Default | What |
|---|---|---|
| `provider` | `gemini` | Same options as `COMMA_CFG` |
| `model` | `gemini-3-pro-preview` | A model with reliable tool-use |
| `tools` | `web_search,nu` | Web search + nushell tool — needed for factcheck/quotes to do real verification |

If unset, the analyze commands always use the defaults above — regardless of what `COMMA_CFG` says. This is intentional: setting `COMMA_CFG.tools = none` globally must not silently disable web search in factcheck.

Override:

```nu
$env.COMMA_ANALYZE_CFG = {
    provider: anthropic
    model: claude-sonnet-4-6
    tools: web_search
}
```

## The `model` command

A convenience wrapper that sets `COMMA_CFG`:

```nu
model <name> [--provider <string>]
```

| Argument | What |
|---|---|
| `name` | Model ID |
| `--provider` | Provider (if changing); otherwise keeps the current provider |

**Example:**

```nu
model claude-sonnet-4-6 --provider anthropic
model gpt-4o --provider openai
model gemini-2.5-pro                          # keeps provider=gemini
```

The new config persists for the rest of the session. `,?` (or `status`) shows the active config.

**Alias:** `,m`

## Module-specific configuration

### `publish.nu`

No environment variables. PDF engine is controlled per-call via `--engine`. Templates are passed per-call via `--template`.

### `research.nu`

No environment variables besides what `iwe` itself reads from your shell (e.g. `IWE_ROOT` if set, or the discovery of `.iwe/` in the current directory tree). Comma does not impose any additional configuration on top of IWE.

## Polish-loop configuration

`polish` has its own per-call flags rather than environment variables:

| Flag | Default | Tunes |
|---|---|---|
| `--lix-min` | 30 | Lower readability bound |
| `--lix-max` | 50 | Upper readability bound |
| `--repeat-min-length` | 4 | n-gram length flagged as repetition |
| `--max-passes` | 4 | Hard pass cap |

See [reference/pipeline](pipeline.md) for the full polish reference.

## Inspecting current config

```nu
,?            # alias for `status` — prints active config + command inventory
status        # same
$env.COMMA_CFG          # raw value
$env.COMMA_ANALYZE_CFG  # if set
```

## Scoping changes to one block

```nu
with-env {COMMA_CFG: {provider: openai, model: gpt-4o, tools: none}} {
    "Hello, world" | tr da
}
```

The override applies only within the block; the original `COMMA_CFG` is restored after.
