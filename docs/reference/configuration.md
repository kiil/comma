---
title: "configuration"
parent: "Reference"
nav_order: 10
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

Used by LLM commands in `analyze` (detect, sentiment, keywords, entities, readability, classify). Separated from `COMMA_CFG` so analyze NLP can be tuned independently.

| Field | Default | What |
|---|---|---|
| `provider` | `gemini` | Same options as `COMMA_CFG` |
| `model` | `gemini-3.1-flash-lite` | Fast, cheap NLP — analyze tasks don't need a stronger model |
| `tools` | `none` | No tools — analyze's commands are pure text-in, text-out |

Override:

```nu
$env.COMMA_ANALYZE_CFG = {
    provider: anthropic
    model: claude-haiku-4-5-20251001
    tools: none
}
```

### `$env.COMMA_VALIDATE_CFG`

Used by `validate` commands (`factcheck`, `quotes`, `claims`). Separated because these need `web_search` to do real verification — without it they would hallucinate citations.

| Field | Default | What |
|---|---|---|
| `provider` | `gemini` | Same options as `COMMA_CFG` |
| `model` | `gemini-3-pro-preview` | A model with reliable tool use and stronger reasoning |
| `tools` | `web_search,nu` | Web search + nushell tool |

Override:

```nu
$env.COMMA_VALIDATE_CFG = {
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

### `convert.nu`

No environment variables. PDF engine is controlled per-call via `--engine`. Templates are passed per-call via `--template`.

### `publish.nu`

Reserved module. No commands exported yet; per-platform configuration will be defined as commands are added.

### `feeds.nu`

`$env.COMMA_FEEDS_PROVIDER` selects the feed-reader backend.

| Value | Backend | Required binary |
|---|---|---|
| `blogtato` (default) | https://github.com/kantord/blogtato | `blog` |

Each provider's data lives wherever that provider stores it — `blogtato` keeps its store at `~/Library/Application Support/blogtato/stores/default` on macOS (or `$RSS_STORE` if set). comma does not interpose its own storage; it shells out and reshapes the output into pipe-friendly tables.

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
