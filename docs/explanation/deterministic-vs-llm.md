---
title: "Deterministic vs. LLM"
parent: "Explanation"
nav_order: 3
---

# Deterministic vs. LLM

When should a comma command use a deterministic algorithm, and when should it call an LLM? This is the design question behind half the commands in `analyze.nu` and most of the architecture of `pipeline.nu`. This page explains how we decide.

## The default: deterministic

The starting point for any new command is: can this be done deterministically?

Word counts, n-gram frequency, sentence splitting, Lix scoring, type-token ratio, Jaccard similarity, repeated-phrase detection, regex extraction — all of these are pure arithmetic and string manipulation. They are:

- **Free.** No API calls, no rate limits, no provider keys.
- **Fast.** Sub-second on documents that would take an LLM 5–30 seconds.
- **Reproducible.** Same input, same output, every time. Critical for testing and trust.
- **Offline.** Works on a plane, on a corporate network without OpenAI access, on a Raspberry Pi.

If the answer to "can this be done deterministically" is yes, that is the implementation.

## The exception: genuine ambiguity

LLMs earn their keep when the task involves:

- **Natural language understanding under ambiguity.** Sentiment, classification into open-ended categories, intent inference.
- **Translation between human languages.** Particularly idioms and register, which dictionaries miss.
- **Generation.** Drafts, expansions, brainstorms.
- **Semantic compression.** Summarization, distillation. (A deterministic summary is a truncation; an LLM summary chooses what matters.)
- **Open-world verification.** Fact-checking against the live web requires both search and judgment.

These are the commands that legitimately use an LLM: `tr`, `rw`, `sum`, `proof`, `tone`, `draft`, `expand`, `title`, `ideas`, `ask`, `detect`, `sentiment`, `keywords`, `entities`, `readability`, `classify`, `factcheck`, `quotes`, `claims`, `distill`, `cite`.

## A few interesting cases

### `readability` (LLM) vs. `lix` (deterministic)

Both assess readability. Why both?

`lix` measures sentence length and long-word percentage. It produces a number and a band ("middle (dailies)"). The number is reproducible.

`readability` (LLM) considers vocabulary, jargon, structure, audience suitability. It produces a qualitative assessment ("hard", "general adult reader", "drives the difficulty: heavy passive voice").

A text can be Lix 35 (middle band) but use specialist jargon that makes it hard for general readers — Lix won't catch that. Conversely, a text can be Lix 55 (hard) but use familiar words in long structures that flow fine — Lix overestimates difficulty.

Both numbers live in `report` because they complement each other. Neither is wrong.

### `sentiment` (LLM only)

There is no deterministic sentiment classifier in comma. Why?

Lexicon-based sentiment (count "happy" words vs. "sad" words) has known failure modes: negation, sarcasm, domain-specific connotation, mixed sentiment. A simple lexicon would give wrong answers on real text often enough that we don't ship one.

An LLM call, even via flash-lite, is fast enough and right enough to be the better choice. We don't pretend determinism where we'd just be approximating poorly.

### `factcheck` (LLM with tools, mandatory)

Factchecking requires:

1. Identifying claims (deterministic at best for "extractive" claims; usually needs understanding)
2. Searching for sources (network call)
3. Evaluating evidence (judgment)

Each step on its own could be a separate command. We bundle them into `factcheck` because the workflow is "verify this draft," not "extract every potentially-checkable string and look each one up." The bundled command goes through an LLM with `web_search` enabled — this is why `analyze` has a separate `COMMA_ANALYZE_CFG` with tools turned on.

## How `polish` uses the split

The critic loop layers them deliberately:

- **Deterministic critics provide stop conditions.** `lix` is in band or it isn't; `repeats` finds duplicates or it doesn't. These give the loop a fixed target.
- **LLM critics catch what determinism misses.** `proof` for mechanics, `readability` for qualitative difficulty.

If we relied only on LLM critics, the loop would never terminate — LLMs always find something. If we relied only on deterministic critics, we'd miss proofreading. Layering is what makes the loop both rigorous and bounded.

## The cost lens

It's not only about quality. The two implementations have wildly different cost profiles:

| | Deterministic | LLM (flash-lite) | LLM (pro-tier) |
|---|---|---|---|
| Latency | <100ms | 1–5s | 5–30s |
| Cost per call | $0 | <$0.001 | $0.01–0.10 |
| Network needed | No | Yes | Yes |
| Reproducible | Yes | No (temperature) | No |
| Scales with document size | Linear | Roughly linear in input + output tokens | Same |

For a polish loop that may run 4 passes with 3 critics each (12 calls), the cost difference between "all LLM" and "deterministic-first" is the difference between a session you don't think about and a session you watch a meter for.

## The user's lever

`report --no-llm` is the user's lever: skip the LLM analysers, get only the deterministic ones. It's not just a cost-saver — it's a baseline. If you want a *definitely-reproducible* analysis you can re-run tomorrow and get identical numbers, `--no-llm` is the way to do it.

`--no-llm` does not exist on every command because it would not always make sense — `sentiment --no-llm` has nothing to do. It exists where the deterministic answer is meaningful on its own.

## In one sentence

Determinism is the default; LLMs are reserved for tasks where ambiguity is structural and judgment is unavoidable; layering them in `polish` is what makes iteration both rigorous and bounded.
