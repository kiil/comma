---
title: "01 — Getting started"
parent: "Tutorials"
nav_order: 1
---

# Tutorial 01 — Getting started

This tutorial gets you from nothing to running your first three comma commands. Allow ten minutes.

## What you will learn

By the end you will have:

1. Loaded the `comma` overlay into your nushell session
2. Translated, proofread and summarized a piece of text
3. Seen the difference between deterministic and LLM-backed commands

## Before you start

You need:

- **nushell** 0.106 or newer (`nu --version` to check)
- **yoke** in your `$PATH` ([install instructions](https://github.com/cablehead/yoke))
- A configured API key for at least one LLM provider (gemini is the default; set `GEMINI_API_KEY` in your environment)

You do *not* need any other tool installed for this tutorial. We will only touch the LLM-backed commands.

## Step 1 — Load the overlay

Clone the repository somewhere convenient and load it as an overlay:

```nu
overlay use /path/to/comma
```

You should see a banner:

```
comma overlay loaded · gemini/gemini-3.1-flash-lite-preview
transform · generate · analyze — ,? for list
```

The first line tells you which model is active. The second is your reminder that the three primary pipeline stages exist; `,?` (an alias for `status`) prints the full command inventory.

Type it now:

```nu
,?
```

You will see all the available commands grouped by module. Don't try to memorize them — we'll meet them one at a time.

## Step 2 — Translate something

Comma's hello-world is translation. Pipe a string into `tr` with a target language:

```nu
"Hello, world" | tr da
```

The output is just the Danish translation — no quotes, no preamble, no markdown:

```
Hej, verden
```

That output style is the comma contract: every command returns plain text on stdout, ready to pipe into the next command.

Try a few variations:

```nu
"Good morning" | tr fransk            # target can be a language name, not just an ISO code
"Hej, hvordan går det?" | tr en --formal   # opt into formal register
```

## Step 3 — Proofread a draft

`proof` corrects spelling, grammar and punctuation while preserving voice:

```nu
"Jeg har set tre hunde igår" | proof
```

Output:

```
Jeg har set tre hunde i går.
```

Two corrections happened: "igår" became "i går" (a Danish spelling rule), and a period was added. `proof` is conservative by default — it does not rewrite for style. If you want it to also tighten awkward phrasing, pass `--strict`:

```nu
"Det var ikke noget der var godt for ham" | proof --strict
```

## Step 4 — Summarize a longer text

Type or paste a longer piece of text, then summarize it:

```nu
"Espresso extraction depends on three variables: grind size, dose, and time. Grind size controls the surface area of coffee exposed to water. Dose is the mass of coffee used. Time is how long water is in contact with the grounds. Together these determine the strength and balance of the shot. Most home baristas tune one variable at a time, holding the other two constant, until the taste lands where they want it." | sum --bullets --max 3
```

Output:

```
- Espresso extraction depends on three variables: grind size, dose, and time.
- These variables together determine the strength and balance of the shot.
- Tune one variable at a time, holding the others constant, until taste is right.
```

The `--bullets` flag asks for a bullet list; `--max 3` caps the length.

## What just happened

You used three commands from `transform.nu`, the part of comma that *rewrites* existing text. The other modules cover:

- `generate.nu` — producing *new* text from a brief
- `analyze.nu` — inspecting text (statistics, classification, NLP)
- `validate.nu` — verifying text against reality (fact-checks, quote attribution)
- `research.nu` — capture and distillation, with bridges to IWE
- `pipeline.nu` — `polish`, an iterative critic loop
- `publish.nu` — render to PDF, HTML, DOCX

Two important properties you should note:

1. **Every command is stateless.** Nothing persists between invocations. The model has no memory of your previous command. This is deliberate — it makes pipelines predictable.

2. **Output is always plain text.** No markdown wrappers, no "Here is the translation:" preamble. You can pipe directly into `save`, `to-pdf`, another comma command, or any nushell command.

## Next steps

- For the end-to-end pipeline (research → draft → polish → publish), continue to [Tutorial 02 — The research-to-publish pipeline](02-the-research-pipeline.md).
- For specific tasks, jump into the [how-to guides](../how-to/).
- For a complete command reference, see [reference](../reference/).
