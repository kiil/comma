---
title: "Appendix: NLP concepts behind analyze"
parent: "Explanation"
nav_order: 5
---

# Appendix: NLP concepts behind analyze

This appendix is a short field guide to the linguistic and statistical ideas that the [`analyze`](../reference/analyze.md) commands implement. It is not a tutorial on using comma — see [analyze text statistically](../how-to/analyze-text-statistically.md) for that. It is a primer on *what* the commands measure and *why* those measures are useful, so you have a mental model when you read their output.

The material is organized into four buckets: lexical metrics, context and sequences, structural analysis, and comparative tools.

## 1. Core lexical metrics

These tools tell you about the "DNA" of the vocabulary used in a text.

### `stats` and `freq`

The bread and butter. [`stats`](../reference/analyze.md#stats) gives the high-level overview — total word count, sentence count, paragraph count, average word length. [`freq`](../reference/analyze.md#freq) counts how often individual words appear.

In NLP we typically filter out *stop words* (`the`, `is`, `at`, `of`) before computing frequencies. Otherwise the most frequent word in any English document is invariably `the`, which is not useful. comma's `freq` ships with stopword sets for English and Danish and lets you supply your own; `--no-stop` disables filtering entirely if you do want to see the function words.

### TTR — Type-token ratio

A measure of *lexical diversity*. The formula:

```
TTR = unique words (types) / total words (tokens)
```

A high TTR (close to 1.0) means the author uses a very diverse vocabulary. A low TTR suggests repetitive language or a narrow topic focus.

Caveats worth knowing:

- TTR is sensitive to text length. Longer texts almost always have lower TTR simply because there are more chances to reuse common words. Comparing TTR across documents of similar length is meaningful; comparing a 200-word email to a 50,000-word novel is not.
- TTR after stopword filtering reflects *content* diversity rather than total diversity. comma defaults to filtering, which is usually what you want for stylistic comparison.

See [`ttr`](../reference/analyze.md#ttr).

### Hapax legomena

Greek for "things said once." These are words that appear exactly one time in a corpus. They are often the "fringe vocabulary" — proper nouns, technical terms, or stylistic flourishes unique to the author.

A high hapax count relative to total vocabulary signals stylistic richness or topic breadth. A near-zero hapax count signals tight, repetitive language (like a manual or a contract).

Hapax counts are also a classic stylometric signal — comparing hapax patterns is part of how literary scholars argue authorship for disputed texts.

See [`hapax`](../reference/analyze.md#hapax).

### Lix — readability index

A formula for text difficulty, originally calibrated against Scandinavian newspapers and now widely used across Northern Europe:

```
Lix = (words / sentences) + (long_words × 100 / words)
```

where a "long word" is any word longer than 6 letters. Sentence length captures structural complexity; long-word percentage captures vocabulary density.

Interpretation bands (Scandinavian standard):

| Score | Difficulty |
|---|---|
| <25 | very easy (children's book) |
| 25–35 | easy (fiction, magazines) |
| 35–45 | medium (daily newspapers) |
| 45–55 | hard (non-fiction) |
| ≥55 | very hard (academic, legal) |

Lix is calibrated to Scandinavian languages, but it gives a useful rough indication in English and German too — just expect the bands to feel slightly conservative.

See [`lix`](../reference/analyze.md#lix). For a qualitative LLM-based reading-level assessment, see [`readability`](../reference/analyze.md#readability) — the two are complementary.

## 2. Context and sequences

These tools tell you how words "hang out" with each other.

### N-grams

Continuous sequences of *n* items from a text:

- **Unigram** (n=1): `the`, `quick`, `brown`
- **Bigram** (n=2): `the quick`, `quick brown`
- **Trigram** (n=3): `the quick brown`

Bigrams and trigrams reveal collocations almost for free. If `dark matter` appears 40 times as a bigram, that's a phrase that matters to the document — not two separate words that happen to co-occur.

In comma, stopwords are filtered *before* the sliding window so bigrams don't span removed words. That keeps the results meaningful — without that, you'd get a lot of `the X` and `of Y` bigrams.

See [`ngrams`](../reference/analyze.md#ngrams).

### KWIC — keyword in context

A concordance view. For every occurrence of your search term, KWIC shows a window of words before and after, putting the term in context.

This is the classic tool of corpus linguistics for one reason: words mean different things in different contexts, and frequency counts alone can't tell you which sense is in play. Is `lead` being used as a verb (`to lead a team`) or a noun (`lead pipes`)? Is `bank` a financial institution or a river edge? KWIC shows you, occurrence by occurrence.

See [`kwic`](../reference/analyze.md#kwic).

### Repeats

Where n-grams use fixed lengths, *repeats* hunts for any multi-word phrase (of a minimum length) that appears more than once. This catches idioms, clichés, and — most usefully for an editor — accidentally duplicated prose in your own drafts.

If `we are committed to delivering` appears 5 times in a 2,000-word document, that's a phrase you didn't mean to write five times. Repeats catches it before your reader does.

See [`repeats`](../reference/analyze.md#repeats).

## 3. Structural analysis

This is how you slice the "pizza" of your text.

### Sentences and paragraphs

This is *segmentation* — finding boundaries between thoughts. It sounds trivial until you try it.

A naive approach splits on `[.!?]` followed by whitespace. That breaks on:

- `Dr. Smith went to the U.S.A. at 5 p.m.` — four false sentence breaks
- `What?!` — multiple terminators
- `She said: "It's fine."` — terminator inside a quote
- `e.g., this list` — `e.g.` doesn't end a sentence

comma uses the naive regex approach because the cost of perfection (a full sentencer with abbreviation lists, machine-learned models, etc.) is not worth it for the readability-and-statistics use case. Expect occasional miscounts on prose with many abbreviations; for legal or medical text where this matters, run paragraphs separately and accept that sentence counts are approximate.

See [`sentences`](../reference/analyze.md#sentences) and [`paragraphs`](../reference/analyze.md#paragraphs). Both return lists, so they compose well: `paragraphs | each {|p| $p | lix}` gives a per-paragraph readability score.

### Extract

The general problem of pulling specific information out of unstructured text. Two named subspecies:

- **Named Entity Recognition (NER)** — extracting people, organizations, places, dates, monetary amounts. comma's [`entities`](../reference/analyze.md#entities) command does this via LLM.
- **Keyword extraction** — finding the most representative words for a document. comma's [`keywords`](../reference/analyze.md#keywords) command does this via LLM, alongside the deterministic [`freq`](../reference/analyze.md#freq) for simple frequency-based extraction.

comma also has a regex-based [`extract`](../reference/analyze.md#extract) for the easier-to-pattern cases: URLs, emails, hashtags and @-mentions. These are not "NLP" in the strict sense — they are pattern matching — but they live in the same module because they answer the same shape of question: "what structured data is hiding in this text?"

## 4. Comparative and advanced tools

### Compare

Looks at two corpora and reports which words are statistically more significant in one over the other.

This is the tool for "how does the State of the Union in 1920 differ from the one in 2020?" or "how is my prose different from this reference author's?" The underlying math here is *log-odds with smoothing*: for each word, score = log₂((rel_freq_in_A + ε) / (rel_freq_in_B + ε)). A positive score means the word is relatively more frequent in A; negative means B. The smoothing constant ε handles words absent in one corpus.

Compared to raw frequency comparison, log-odds is better-behaved on small corpora and gives intuitive symmetric scores (a word being 2× more frequent in A scores the same magnitude as 2× more frequent in B, just opposite sign).

See [`compare`](../reference/analyze.md#compare).

### Similar

In comma, `similar` is *Jaccard similarity over k-shingles*: split each text into overlapping k-word windows, treat the windows as sets, return `|intersection| / |union|`. This is a syntactic measure — two paraphrased versions of the same idea will score low because they share few k-shingles.

True semantic similarity needs *word embeddings*: each word (or document) becomes a vector in a high-dimensional space, and similarity is computed via *cosine similarity* on those vectors. That captures synonymy and paraphrasing — but it requires a model, vector storage, and an embeddings pipeline.

comma deliberately stops at shingle-based similarity because it's deterministic, fast, plugin-free, and good enough for the realistic use cases (near-duplicate detection, plagiarism scanning, style-consistency checks across a single author's drafts). For genuine semantic search across a corpus, reach for a dedicated tool.

See [`similar`](../reference/analyze.md#similar).

### Report

The final synthesis. [`report`](../reference/analyze.md#report) runs every relevant deterministic analyzer plus the lighter LLM ones (sentiment, keywords, detect, readability) and bundles the result into a single structured record.

Useful both as a one-shot "tell me everything about this text" command and as a structured input to downstream tools — `report --no-llm | to yaml` gives you a stable, reproducible snapshot you can diff over time, version in git, or feed into your own dashboards.

## A note on Zipf's law

When you look at the output of [`freq`](../reference/analyze.md#freq) or [`hapax`](../reference/analyze.md#hapax), keep [Zipf's law](https://en.wikipedia.org/wiki/Zipf%27s_law) in mind.

In essentially every natural language, the *n*-th most frequent word appears with frequency roughly proportional to *1/n*. The most frequent word appears about twice as often as the second, three times as often as the third, ten times as often as the tenth. Plotted log-log, you get a near-straight line.

This has a practical consequence: in any corpus large enough to be interesting, a tiny number of words account for most of the tokens, while a long tail of words appear only once or twice (the hapax legomena). Your `freq --top 20` output will be dominated by a handful of repeats and then drop off rapidly; that is normal.

If your data does *not* look like that — if frequencies are too flat, or too peaked — you have either an unusual corpus (a controlled vocabulary, an artificially generated text) or you forgot to filter stopwords.

## Where these concepts touch other comma modules

- [`polish`](../reference/pipeline.md) uses `lix` (readability bound) and `repeats` (phrase deduplication) as its deterministic critics. The critic loop's stop condition is essentially "these metrics are within target ranges."
- [`distill`](../reference/research.md#distill) produces a structured study note whose "Keywords" section is conceptually the same task as `keywords`, just bundled into a larger LLM call.
- [`compare`](../reference/analyze.md#compare) pairs naturally with [`research.cite`](../reference/research.md#cite) for stylistic studies: extract quotes from corpus A, compare against corpus B.

## Further reading

The classical reference for corpus linguistics is McEnery and Hardie, *Corpus Linguistics: Method, Theory and Practice* (Cambridge, 2012). For computational treatments of frequency, n-grams and segmentation, Jurafsky and Martin's *Speech and Language Processing* is the standard textbook — freely available at <https://web.stanford.edu/~jurafsky/slp3/>.
