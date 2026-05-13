---
title: "analyze"
parent: "Reference"
nav_order: 3
---

# Reference: analyze

Commands that inspect text and return insight. Split into deterministic (free, offline) and LLM-backed (text-only NLP, no tools).

The LLM commands use `$env.COMMA_ANALYZE_CFG` (default: `gemini-3.1-flash-lite` with no tools) instead of the main `COMMA_CFG`. See [configuration](configuration.md).

Verification commands that need web search (`factcheck`, `quotes`, `claims`) live in their own [validate](validate.md) module with a stronger default model and tools enabled.

## Deterministic commands

### `stats`

Basic counts via nushell's `str stats` plus sentence/paragraph/word stats.

```
stats [--verbose] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-v, --verbose` | off | Also include top words, shortest/longest word lengths |

Returns a record with: `lines`, `words`, `bytes`, `chars`, `graphemes`, `unicode-width`, `sentences`, `paragraphs`, `avg_word_length` (plus `top_words`, `shortest_word_length`, `longest_word_length` when verbose).

**Alias:** `,st`

### `freq`

Word frequency, stopword-filtered.

```
freq [--lang <string>] [--top <int>] [--no-stop] [--stop <list>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-l, --lang` | `en` | Stopword set: `en`, `da`, or `none` |
| `-n, --top` | 50 | Top-N results (0 = all) |
| `--no-stop` | off | Skip stopword filtering entirely |
| `--stop` | — | Custom stopword list (overrides `--lang`) |

Returns a table with `value` and `count` columns, sorted descending.

**Alias:** `,fq`

### `ngrams`

Bigram/trigram frequency.

```
ngrams [--n <int>] [--top <int>] [--lang <string>] [--no-stop] [...text]
```

| Flag | Default | What |
|---|---|---|
| `--n` | 2 | Window size (2 = bigrams, 3 = trigrams) |
| `--top` | 30 | Top-N results |
| `-l, --lang` | `en` | Stopword set |
| `--no-stop` | off | Skip stopword filtering |

Stopword filter runs before the window so grams don't span filtered words.

**Alias:** `,ng`

### `kwic`

Keyword-in-context concordance.

```
kwic <keyword> [--window <int>] [--case-sensitive] [...text]
```

| Flag | Default | What |
|---|---|---|
| `keyword` | required | Word to find |
| `-w, --window` | 5 | Words of context on each side |
| `--case-sensitive` | off | Match case |

Returns a table with `pos`, `left`, `match`, `right` columns.

**Alias:** `,kc`

### `lix`

Scandinavian-standard Lix readability score.

```
lix [...text]
```

Returns a record: `lix`, `sentences`, `words`, `long_words`, `avg_sentence_length`, `long_word_pct`, `interpretation`. Long word = >6 letters.

Interpretation bands: very easy (<25), easy (25–35), middle (35–45), hard (45–55), very hard (≥55).

**Alias:** `,lx`

### `repeats`

Repeated multi-word phrases.

```
repeats [--min-length <int>] [--min-count <int>] [--top <int>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-l, --min-length` | 4 | Minimum phrase length (words) |
| `-c, --min-count` | 2 | Minimum repetition count |
| `--top` | 20 | Top-N results |

**Alias:** `,rp`

### `compare`

Distinctive words in A versus B via smoothed log-odds.

```
compare <other> [--top <int>] [--lang <string>] [--no-stop] [...text]
```

| Flag | Default | What |
|---|---|---|
| `other` | required | Comparison text or filepath |
| `-n, --top` | 15 | Top-N distinctive per side |
| `-l, --lang` | `en` | Stopword set |
| `--no-stop` | off | Skip stopword filtering |

Returns a record with `distinctive_in_a` and `distinctive_in_b` tables. Score is base-2 log of the smoothed relative-frequency ratio: positive = more in A.

**Alias:** `,cp`

### `hapax`

Words appearing exactly once.

```
hapax [--lang <string>] [--no-stop] [...text]
```

**Alias:** `,hp`

### `ttr`

Type-token ratio (`unique_words / total_words`).

```
ttr [--lang <string>] [--no-stop] [...text]
```

Returns a record: `types`, `tokens`, `ttr`.

**Alias:** `,tt`

### `similar`

Jaccard similarity between two texts via k-shingles.

```
similar <other> [--k <int>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `other` | required | Comparison text or filepath |
| `--k` | 3 | Shingle size (words) |

Returns `{jaccard, shared, total}`.

**Alias:** `,sl`

### `sentences`

Split text into sentences (regex on `[.!?]+\s+`).

```
sentences [...text]
```

Returns a list of strings.

**Alias:** `,sn`

### `paragraphs`

Split text into paragraphs (regex on blank lines).

```
paragraphs [...text]
```

Returns a list of strings.

**Alias:** `,pa`

### `extract`

Regex extraction of structured data.

```
extract [--kind <string>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-k, --kind` | `url` | One of `url`, `email`, `hashtag`, `mention` |

Returns a deduplicated list of matches.

**Alias:** `,xt`

### `report`

Run all deterministic analyzers (plus the LLM ones unless `--no-llm`) and return a single structured record.

```
report [--no-llm] [--lang <string>] [--top <int>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `--no-llm` | off | Skip LLM commands (sentiment, keywords, detect, readability) |
| `-l, --lang` | `en` | Stopword set |
| `-n, --top` | 15 | Top-N for freq, ngrams, keywords |

Returns nested records: `meta`, `readability`, `lexical`, `top_words`, `top_bigrams`, `top_trigrams`, `repeated_phrases`, `extracted`, `llm` (unless `--no-llm`).

**Alias:** `,rt`

## LLM-backed commands

These use `$env.COMMA_ANALYZE_CFG` and may make web requests.

### `detect`

Identify the dominant language.

```
detect [--name] [...text]
```

| Flag | Default | What |
|---|---|---|
| `--name` | off | Return English language name instead of ISO 639-1 code |

**Alias:** `,de`

### `sentiment`

Classify overall sentiment.

```
sentiment [--score] [...text]
```

| Flag | Default | What |
|---|---|---|
| `--score` | off | Include float score in [-1.0, 1.0] |

Returns `positive`, `neutral` or `negative`. With `--score`: `<label> (<score>)`.

**Alias:** `,se`

### `keywords`

Top-N keywords/key phrases.

```
keywords [--count <int>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-n, --count` | 10 | Number of keywords |

**Alias:** `,kw`

### `entities`

Extract named entities.

```
entities [--kind <string>] [...text]
```

| Flag | Default | What |
|---|---|---|
| `-k, --kind` | all | Filter: `person`, `place`, `org`, `date`, `money` |

Output format: one per line, `<text> — <type>`.

**Alias:** `,en`

### `readability`

Qualitative reading level assessment.

```
readability [...text]
```

Returns three lines: `level: <very easy|easy|medium|hard|very hard>`, `audience: <noun phrase>`, `notes: <one-sentence reason>`.

**Alias:** `,rd`

### `classify`

Pick the best-fit label from a list.

```
classify [--multi] ...labels
```

| Flag | Default | What |
|---|---|---|
| `--multi` | off | Allow multiple labels (comma-separated output) |
| `...labels` | ≥2 required | The candidate labels |

Input text must come via pipe.

**Alias:** `,cl`

## Verification commands

`factcheck`, `quotes` and `claims` moved to a separate [validate](validate.md) module so analyze can default to a lighter, tool-free model. See the validate reference for their signatures.
