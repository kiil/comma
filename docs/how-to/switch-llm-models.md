---
title: "Switch LLM models"
parent: "How-to guides"
nav_order: 7
---

# How to switch LLM models

## Goal

Change which LLM provider and model comma uses — for the whole session, for one module, or for a single command.

## How comma uses models

Three configs:

| Config | Used by | Default |
|---|---|---|
| `$env.COMMA_CFG` | `transform`, `generate`, `research` (and `pipeline`'s LLM critics) | gemini / gemini-3.1-flash-lite-preview / tools=none |
| `$env.COMMA_ANALYZE_CFG` | `analyze` LLM commands (detect, sentiment, keywords, entities, readability, classify) | gemini / gemini-3.1-flash-lite / tools=none |
| `$env.COMMA_VALIDATE_CFG` | `validate` (factcheck, quotes, claims) | gemini / gemini-3-pro-preview / tools=web_search,nu |

Why three? `validate`'s `factcheck` and `quotes` need `web_search` to do real verification — letting them inherit `tools=none` would turn them into hallucination machines. `analyze` is split out so its lighter NLP commands can use a cheaper model without affecting validation. Three configs keeps each module's defaults sensible without forcing one-size-fits-all.

## Change the global default for the session

Use the `model` command:

```nu
model claude-sonnet-4-6 --provider anthropic
```

This sets `$env.COMMA_CFG.provider` and `$env.COMMA_CFG.model`. The change persists for the rest of the session (or until you change it again).

Confirm with `,?` (or `status`):

```nu
,?
```

The first config line should now show the new model.

## Set both explicitly

```nu
$env.COMMA_CFG = {
    provider: openai
    model: gpt-4o
    tools: none
}
```

Tools other than `none` are: `all`, `code`, `web_search`, or any comma-separated subset of `bash, nu, read_file, write_file, edit_file, list_files, search, web_search`. Be careful — most comma transform/generate commands assume `tools=none` so the model can't escape to other systems mid-rewrite.

## Override analyze separately

```nu
$env.COMMA_ANALYZE_CFG = {
    provider: anthropic
    model: claude-haiku-4-5-20251001
    tools: none
}
```

This affects `detect`, `sentiment`, `keywords`, `entities`, `readability`, `classify`. The deterministic commands (`stats`, `freq`, `lix`, etc.) are unaffected — they never touch an LLM.

## Override validate separately

```nu
$env.COMMA_VALIDATE_CFG = {
    provider: anthropic
    model: claude-sonnet-4-6
    tools: web_search
}
```

This affects `factcheck`, `quotes`, `claims`. Keep tools enabled — `factcheck` and `quotes` rely on `web_search` to verify against real sources.

## One-off model for a single command

There is no `--model` flag on individual commands (intentional — it would clutter every signature). The pattern is to set the env temporarily:

```nu
with-env {COMMA_CFG: {provider: openai, model: gpt-4o, tools: none}} {
    "Hello, world" | tr da
}
```

This scopes the override to the block and restores the previous setting after.

## Why no Claude-by-default

The default of `gemini-3.1-flash-lite-preview` is chosen because:

- It is fast for the volume of small calls comma makes (proof, translate, summarize)
- It is cheap, which matters for `polish` loops that may make a dozen calls
- It is good enough for most rewrites

For higher-stakes work — a long publication-bound draft, a fact-check with consequence — switch to a stronger model with `model claude-sonnet-4-6 --provider anthropic` or via `COMMA_VALIDATE_CFG`.

## When the model matters most

| Task | Model sensitivity |
|---|---|
| `tr` (translation) | Medium — flash-lite is fine for European languages, weaker for translation between unrelated languages |
| `proof` | Low — mechanical corrections are easy |
| `factcheck`, `quotes` | High — needs real `web_search` + careful reasoning |
| `distill` | Medium — structure follows the prompt, quality of extraction varies |
| `draft` with `--notes` | Low–medium — the grounding does most of the work |
| `polish` | Low — small targeted patches |

## Related

- [reference/configuration](../reference/configuration.md) — full env var reference
- [Explanation: deterministic vs. LLM](../explanation/deterministic-vs-llm.md) — when model choice doesn't matter at all
