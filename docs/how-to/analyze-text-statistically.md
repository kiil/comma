---
title: "Analyze text statistically"
parent: "How-to guides"
nav_order: 3
---

# How to analyze text statistically

## Goal

Get quantitative facts about a text — length, readability, frequency, repetition — without spending LLM tokens.

## The all-in-one report

If you want everything at once:

```nu
open --raw text.md | report --lang en --top 15 --no-llm
```

`report` aggregates `stats`, `lix`, `ttr`, `freq`, `ngrams` (bi and tri), `hapax`, `repeats` and `extract` into one structured record. `--no-llm` skips the LLM-backed extras (sentiment, keywords, detect, readability) so it stays deterministic.

To get yaml or json output, pipe through `to yaml` / `to json`:

```nu
open --raw text.md | report --no-llm | to yaml
```

## Individual commands

### Basic counts

```nu
open --raw text.md | stats
```

Returns lines, words, bytes, chars, graphemes, sentences, paragraphs and average word length. `stats --verbose` adds top word frequencies and word length extremes.

### Readability

```nu
open --raw text.md | lix
```

Returns the Lix score plus a Scandinavian-standard interpretation band:

```
lix: 41.2
sentences: 14
words: 312
long_words: 78
avg_sentence_length: 22.29
long_word_pct: 25.00
interpretation: middel (dagblade)
```

Lix is calibrated for Scandinavian languages but works as a rough indicator in English too.

### Word frequency

```nu
open --raw text.md | freq --lang en --top 20
```

Returns a table of `value`/`count` rows after stopword filtering. Built-in stopword sets: `en` and `da`. Pass `--no-stop` to skip filtering or `--stop [list]` for a custom set.

### N-grams

```nu
open --raw text.md | ngrams --n 2 --top 20    # bigrams
open --raw text.md | ngrams --n 3 --top 10    # trigrams
```

### Repeated phrases (editor's tool)

Find accidentally duplicated multi-word phrases:

```nu
open --raw text.md | repeats --min-length 4 --min-count 2
```

Phrases of 4+ words that appear 2+ times. Useful for catching unconscious repetition in long drafts.

### Lexical richness

```nu
open --raw text.md | ttr
```

Type-token ratio: `unique_words / total_words`. Higher = more vocabulary variation. Above 0.5 is usually solid for non-fiction; fiction often runs higher.

### Hapax legomena

```nu
open --raw text.md | hapax
```

Words that appear exactly once. A high count signals lexical variety; a low count signals repetition. Classic stylometric measure.

### Concordance (keyword in context)

```nu
open --raw text.md | kwic espresso --window 5
```

For each occurrence of "espresso", show 5 words before and 5 after. Pure corpus-linguistic tool — see how a term is actually used.

### Compare two texts

```nu
open --raw mine.md | compare reference.md --top 15
```

Returns two lists: words distinctive to your text, and words distinctive to the reference. Useful for stylistic positioning.

### Similarity

```nu
open --raw chapter1.md | similar chapter2.md --k 4
```

Jaccard similarity over 4-word shingles. Score in [0, 1]; higher = more similar. Useful for near-duplicate detection or style consistency checks.

### Extract structured data

```nu
open --raw text.md | extract --kind url      # all URLs
open --raw text.md | extract --kind email    # all emails
open --raw text.md | extract --kind hashtag  # all #tags
open --raw text.md | extract --kind mention  # all @handles
```

## Per-paragraph analysis

`sentences` and `paragraphs` are primitives that turn text into lists. Compose them with any of the above:

```nu
open --raw text.md | paragraphs | each {|p| $p | lix}
```

Returns a Lix score per paragraph. Spot the dense ones.

```nu
open --raw text.md | sentences | length
```

Total sentence count (faster than reading `stats.sentences` if that's all you want).

## Cost

Everything on this page runs locally — no network, no tokens. The slowest operation is reading the file. For very large corpora (book-length), word-frequency operations take seconds; everything else is sub-second.

If you want LLM-backed analyses (sentiment, named entities, factcheck, qualitative readability assessment), see [reference/analyze](../reference/analyze.md). They live in the same module but are marked separately.

## Related

- [reference/analyze](../reference/analyze.md) — full flag reference
- [Explanation: deterministic vs. LLM](../explanation/deterministic-vs-llm.md) — when to reach for each
