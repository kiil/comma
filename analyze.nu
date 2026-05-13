# comma · analyze — commands that inspect text and return insight.
#
# Output is still plain text (for pipe-friendliness), but it is a
# description OF the input — not a rewrite of it.
#
# The analyze commands here are either deterministic (stats, freq, lix, …)
# or LLM-backed without tools (detect, sentiment, keywords, entities,
# readability, classify). Verification tasks that need web_search
# (factcheck, quotes, claims) live in validate.nu with their own tool set.
# Override via $env.COMMA_ANALYZE_CFG.

const PROVIDER = "gemini"
const MODEL    = "gemini-3.1-flash-lite"
const TOOLS    = "none"

const PURITY_RULE = "Output requirements (strict):
- Return ONLY the analysis result in the exact format requested.
- Do not wrap in quotes, code fences, or markdown.
- Do not add a preamble, label, explanation, or trailing commentary.
- No hedging (\"it seems\", \"likely\") unless explicitly asked for confidence."

def comma-input [piped: any, args: list<string>] {
    let joined = $args | str join " "
    if ($args | is-not-empty) { return $joined }
    if $piped == null {
        error make {msg: "comma: pipe a string in or pass text as an argument"}
    }
    if ($piped | describe) == "string" { return $piped }
    $piped | to text
}

def comma-call [system: string, user: string] {
    # Analyze uses its own COMMA_ANALYZE_CFG separate from COMMA_CFG so users
    # can choose a stronger model for classification and NLP tasks without
    # moving transform/generate over to the same model.
    let c = $env | get COMMA_ANALYZE_CFG? | default {
        provider: $PROVIDER
        model: $MODEL
        tools: $TOOLS
    }
    let full_system = $"($system)\n\n($PURITY_RULE)"
    let sys_record = {role: "system", content: [{type: "text", text: $full_system}]} | to json -r
    let records = $sys_record
        | ^yoke --provider $c.provider --model $c.model --tools $c.tools $user
        | lines
        | each {|l| try { $l | from json } catch { null } }
        | compact
    let assistant = $records | where { $in | get role? | $in == "assistant" } | last
    if $assistant == null {
        error make {msg: $"comma-call: no assistant response from yoke \(provider=($c.provider), model=($c.model)\). The model may be unavailable, rate-limited, or the request was interrupted."}
    }
    $assistant
        | get content
        | each {|b| if ($b | get type?) == "text" { $b.text } else { null } }
        | compact
        | str join ""
        | str trim
}

# Deterministic counts over a text. Uses nu's `str stats` as a base and
# adds sentence, paragraph and word statistics. No LLM involved — the
# same text always produces the same numbers.
#
#   "Hello world. This is a test." | stats
#   open article.md | stats --verbose
export def stats [
    --verbose (-v)             # also include top-word frequency and word-length extremes
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let base = $src | str stats
    let sentences = $src | split row -r '[.!?]+\s+' | where ($it | str trim | is-not-empty) | length
    let paragraphs = $src | split row -r '\n\s*\n' | where ($it | str trim | is-not-empty) | length
    let words = $src | split words
    let avg_word_length = if ($words | is-empty) { 0.0 } else {
        $words | each {|w| $w | str length} | math avg | math round --precision 2
    }
    let summary = $base | merge {
        sentences: $sentences
        paragraphs: $paragraphs
        avg_word_length: $avg_word_length
    }
    if not $verbose { return $summary }
    let top_words = $words
        | each {|w| $w | str downcase}
        | uniq -c
        | sort-by count --reverse
        | first 10
    let word_lengths = $words | each {|w| $w | str length}
    $summary | merge {
        shortest_word_length: ($word_lengths | math min)
        longest_word_length: ($word_lengths | math max)
        top_words: $top_words
    }
}

# Word-frequency analysis. Deterministic: downcase → split words → stopword
# filter → uniq -c → sort. Pattern from kiils.dk's nushell bible analysis.
#
#   open book.txt | freq
#   open article.md | freq --lang da --top 20
#
# Returns a table with columns `value` and `count`, sorted descending.
# For very large corpora the polars version from the article can be ~10x
# faster — it is not included here to avoid the plugin dependency.
export def freq [
    --lang (-l): string = "en" # stopword set: en | da | none
    --top (-n): int = 50       # most frequent words (0 = all)
    --no-stop                  # skip stopword filtering entirely
    --stop: list<string>       # custom stopword list (overrides --lang)
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let words = $src | str downcase | split words
    let stop_list = if $no_stop {
        []
    } else if $stop != null {
        $stop
    } else {
        stopwords-for $lang
    }
    let counted = $words
        | where {|w| not ($w in $stop_list)}
        | uniq -c
        | sort-by count --reverse
    if $top > 0 { $counted | first $top } else { $counted }
}

# Built-in stopword sets. Kept short and pragmatic —
# users can always pass their own list via --stop.
def stopwords-for [lang: string]: nothing -> list<string> {
    match $lang {
        "en" => [
            a an and are as at be but by for from has have he her his i if in is it
            its me my no not of on or our she so that the their them they this to was we
            were what when where which who will with you your
        ]
        "da" => [
            af alle alt anden at bare blev blive bliver da de dem den denne der deres det
            dette dig din dine disse dog du efter eller en end er et fik for fra ham han
            hans har havde have hende hendes her hos hun i ikke ind jeg jer jeres jo kan
            kun kunne lige med meget mellem men mig min mine må ned nej nogen noget nu når
            og også om op os over på selv sig sin sine sit skal skulle som så til var ved
            vi vil ville vor vores være været
        ]
        "none" => []
        _ => (error make {msg: $"freq: unknown --lang '($lang)' \(use en, da or none\)"})
    }
}

# Helper: check whether a string is an existing filepath, safely (inline
# text may contain characters that make `path exists` fail).
def is-file [s: string]: nothing -> bool {
    if ($s | str length) > 4096 { return false }
    if ($s | str contains "\n") { return false }
    try { $s | path exists } catch { false }
}

# Helper: load text — either directly or from a filepath.
def load-text [s: string]: nothing -> string {
    if (is-file $s) { open --raw $s } else { $s }
}

# N-gram frequency. Default: bigrams. Stopword filtering runs BEFORE the
# windowing so grams don't span removed words.
#
#   open book.txt | ngrams --n 2 --top 20
#   "the quick brown fox jumps over the lazy dog" | ngrams --n 3
export def ngrams [
    --n: int = 2               # window size (2 = bigrams, 3 = trigrams)
    --top: int = 30
    --lang (-l): string = "en"
    --no-stop
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let stop_list = if $no_stop { [] } else { stopwords-for $lang }
    let words = $src | str downcase | split words | where {|w| not ($w in $stop_list)}
    if ($words | length) < $n { return [] }
    let counted = $words
        | window $n
        | each {|w| $w | str join ' '}
        | uniq -c
        | sort-by count --reverse
    if $top > 0 { $counted | first $top } else { $counted }
}

# Keyword-in-context (KWIC). For every occurrence of a search term, show a
# window of words before and after — the classic concordance view.
#
#   open book.txt | kwic god --window 6
export def kwic [
    keyword: string            # the word to find
    --window (-w): int = 5     # words on each side
    --case-sensitive
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let words = if $case_sensitive { $src | split words } else { $src | str downcase | split words }
    let needle = if $case_sensitive { $keyword } else { $keyword | str downcase }
    let n = $words | length
    $words
        | enumerate
        | where item == $needle
        | each {|hit|
            let i = $hit.index
            let lo = if $i < $window { 0 } else { $i - $window }
            let left_take = $i - $lo
            let right_take = if ($i + 1 + $window) > $n { $n - $i - 1 } else { $window }
            {
                pos: $i
                left: ($words | skip $lo | take $left_take | str join ' ')
                match: $hit.item
                right: ($words | skip ($i + 1) | take $right_take | str join ' ')
            }
        }
}

# Lix readability score (Scandinavian standard). Pure arithmetic.
# Lix = words/sentences + (long_words × 100 / words), where "long" = >6 letters.
#
#   open draft.md | lix
export def lix [
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let sentences = $src | split row -r '[.!?]+\s+' | where ($it | str trim | is-not-empty)
    let words = $src | split words
    let n_words = $words | length
    let n_sent = $sentences | length
    if $n_sent == 0 or $n_words == 0 {
        error make {msg: "lix: no sentences or words to measure"}
    }
    let long = $words | where {|w| ($w | str length) > 6} | length
    let asl = ($n_words / $n_sent)
    let lwp = ($long * 100 / $n_words)
    let lix = ($asl + $lwp)
    let bands = [
        [threshold, label];
        [25,    "very easy (children's book)"]
        [35,    "easy (fiction, magazines)"]
        [45,    "medium (daily newspapers)"]
        [55,    "hard (non-fiction)"]
        [99999, "very hard (academic, legal)"]
    ]
    let interp = $bands | where threshold > $lix | first | get label
    {
        lix: ($lix | math round --precision 1)
        sentences: $n_sent
        words: $n_words
        long_words: $long
        avg_sentence_length: ($asl | math round --precision 2)
        long_word_pct: ($lwp | math round --precision 2)
        interpretation: $interp
    }
}

# Find repeated phrases in a text — catches accidental prose duplication.
#
#   open draft.md | repeats
#   open long.md | repeats --min-length 5 --min-count 3
export def repeats [
    --min-length (-l): int = 4 # minimum words per phrase
    --min-count (-c): int = 2  # minimum number of occurrences
    --top: int = 20
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let words = $src | str downcase | split words
    if ($words | length) < $min_length { return [] }
    let counted = $words
        | window $min_length
        | each {|w| $w | str join ' '}
        | uniq -c
        | where count >= $min_count
        | sort-by count --reverse
    if $top > 0 { $counted | first $top } else { $counted }
}

# Compare two texts — distinctive words for each. Uses smoothed log-odds:
# positive score = word is relatively more frequent in A, negative = in B.
# The `other` input can be a text string or a filepath.
#
#   open mine.md | compare reference.md
#   "..." | compare "..." --top 20 --lang da
export def compare [
    other: string              # text or filepath
    --top (-n): int = 15
    --lang (-l): string = "en"
    --no-stop
    ...text: string
] {
    let piped = $in
    let a_src = comma-input $piped $text
    let b_src = load-text $other
    let stop_list = if $no_stop { [] } else { stopwords-for $lang }
    let a_words = $a_src | str downcase | split words | where {|w| not ($w in $stop_list)}
    let b_words = $b_src | str downcase | split words | where {|w| not ($w in $stop_list)}
    let a_total = $a_words | length
    let b_total = $b_words | length
    if $a_total == 0 or $b_total == 0 {
        error make {msg: "compare: one of the texts is empty"}
    }
    let a_freq = $a_words | uniq -c
    let b_freq = $b_words | uniq -c
    let a_map = $a_freq | reduce --fold {} {|row, acc| $acc | upsert $row.value $row.count}
    let b_map = $b_freq | reduce --fold {} {|row, acc| $acc | upsert $row.value $row.count}
    let universe = ($a_map | columns | append ($b_map | columns) | uniq)
    let scored = $universe | each {|w|
        let a_c = ($a_map | get --optional $w | default 0)
        let b_c = ($b_map | get --optional $w | default 0)
        let a_rel = ($a_c + 0.5) / ($a_total + 0.5)
        let b_rel = ($b_c + 0.5) / ($b_total + 0.5)
        let score = ($a_rel / $b_rel) | math log 2
        {word: $w, a: $a_c, b: $b_c, score: ($score | math round --precision 2)}
    }
    {
        distinctive_in_a: ($scored | sort-by score --reverse | first $top)
        distinctive_in_b: ($scored | sort-by score | first $top)
    }
}

# Hapax legomena — words that appear exactly once. Stylometric signal.
#
#   open novel.md | hapax
export def hapax [
    --lang (-l): string = "en"
    --no-stop
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let stop_list = if $no_stop { [] } else { stopwords-for $lang }
    $src | str downcase | split words
        | where {|w| not ($w in $stop_list)}
        | uniq -c
        | where count == 1
        | get value
        | sort
}

# Type-token ratio (lexical variation). 1.0 = every word is unique.
#
#   open draft.md | ttr
export def ttr [
    --lang (-l): string = "en"
    --no-stop
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let stop_list = if $no_stop { [] } else { stopwords-for $lang }
    let words = $src | str downcase | split words | where {|w| not ($w in $stop_list)}
    let tokens = $words | length
    if $tokens == 0 {
        error make {msg: "ttr: no words to measure"}
    }
    let types = $words | uniq | length
    {
        types: $types
        tokens: $tokens
        ttr: ($types / $tokens | math round --precision 3)
    }
}

# Jaccard similarity between two texts via k-shingles (k words at a time).
# Returns a score in [0,1] — higher = more similar.
#
#   open chapter1.md | similar chapter2.md --k 4
export def similar [
    other: string              # text or filepath
    --k: int = 3               # shingle size (words)
    ...text: string
] {
    let piped = $in
    let a_src = comma-input $piped $text
    let b_src = load-text $other
    let a_words = $a_src | str downcase | split words
    let b_words = $b_src | str downcase | split words
    if ($a_words | length) < $k or ($b_words | length) < $k {
        return {jaccard: 0.0, shared: 0, total: 0}
    }
    let a_set = $a_words | window $k | each {|w| $w | str join ' '} | uniq
    let b_set = $b_words | window $k | each {|w| $w | str join ' '} | uniq
    let inter = $a_set | where {|x| $x in $b_set} | length
    let union = $a_set | append $b_set | uniq | length
    {
        jaccard: ($inter / $union | math round --precision 4)
        shared: $inter
        total: $union
    }
}

# Split text into sentences as a list — composes well with other commands.
#
#   open article.md | sentences | each {|s| $s | lix}
export def sentences [
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    $src | split row -r '[.!?]+\s+'
        | each {|s| $s | str trim}
        | where ($it | is-not-empty)
}

# Split text into paragraphs as a list.
#
#   open book.md | paragraphs | each {|p| $p | stats}
export def paragraphs [
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    $src | split row -r '\n\s*\n'
        | each {|p| $p | str trim}
        | where ($it | is-not-empty)
}

# Regex extraction of URLs, emails, hashtags or @-mentions.
#
#   open notes.md | extract --kind url
#   "tweet @somebody about #nushell" | extract --kind hashtag
export def extract [
    --kind (-k): string = "url"  # url | email | hashtag | mention
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let pattern = match $kind {
        "url"     => '(?P<m>https?://[^\s\)\]\}<>"]+|www\.[^\s\)\]\}<>"]+)'
        "email"   => '(?P<m>[\w.+-]+@[\w-]+\.[\w.-]+)'
        "hashtag" => '(?P<m>#\w+)'
        "mention" => '(?P<m>@\w+)'
        _ => (error make {msg: $"extract: unknown --kind '($kind)' \(use url, email, hashtag or mention\)"})
    }
    $src | parse --regex $pattern | get m | uniq
}

# Detect the language of a text. Returns an ISO 639-1 code by default.
#
#   "god morgen" | detect           # => da
#   "god morgen" | detect --name    # => Danish
export def detect [
    --name                     # return the English language name instead of an ISO code
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let fmt = if $name {
        "the English name of the language (e.g. \"Danish\", \"German\", \"French\")"
    } else {
        "the ISO 639-1 two-letter code in lowercase (e.g. \"da\", \"de\", \"fr\")"
    }
    let sys = $"You are a language identifier. Identify the dominant language of the user's text. Return only ($fmt) and nothing else."
    comma-call $sys $src
}

# Sentiment analysis. Default: one word (positive/neutral/negative).
#
#   "love this product" | sentiment           # => positive
#   "love this product" | sentiment --score   # => positive (0.85)
export def sentiment [
    --score                    # include a numeric score in [-1, 1]
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let fmt = if $score {
        "Exactly one line: \"<label> (<score>)\" where label is one of positive, neutral, negative and score is a float in [-1.0, 1.0] with two decimals."
    } else {
        "Exactly one word: positive, neutral, or negative. Lowercase. Nothing else."
    }
    let sys = $"You are a sentiment classifier. Determine the overall sentiment of the user's text. ($fmt)"
    comma-call $sys $src
}

# Extract keywords / key phrases from a text.
#
#   open article.md | keywords
#   keywords --count 5 "long text..."
export def keywords [
    --count (-n): int = 10     # number of keywords
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let sys = $"You are a keyword extractor. Extract the ($count) most important keywords or short key phrases from the user's text. One per line, lowercase unless the term is a proper noun, no numbering, no bullets, no explanations. Order by importance. Match the source language."
    comma-call $sys $src
}

# Extract named entities (people, places, organizations, dates, money).
#
#   open minutes.md | entities
#   entities --kind person "..."
export def entities [
    --kind (-k): string        # filter: person | place | org | date | money
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let filter = if $kind != null {
        $"Only include entities of type: ($kind)."
    } else {
        "Include all types."
    }
    let sys = $"You are a named-entity extractor. From the user's text, extract every named entity. ($filter) Output one entity per line as \"<text> — <type>\" where type is one of: person, place, org, date, money, other. No numbering, no duplicates. If no entities are found, return an empty string."
    comma-call $sys $src
}

# Assess readability (difficulty level, audience, key driver).
#
#   open draft.md | readability
export def readability [
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let sys = "You are a readability analyst. Assess the user's text and return exactly three lines:
level: <one of: very easy, easy, medium, hard, very hard>
audience: <a short noun phrase describing the typical reader, e.g. \"general adult reader\", \"university student\", \"domain expert\">
notes: <one sentence on what drives the difficulty (sentence length, vocabulary, jargon, structure)>
Match the source language for the notes line; keep the keys in English."
    comma-call $sys $src
}

# Classify a text into one of the given categories.
#
#   "can you send me an invoice?" | classify support sales billing
#   classify --multi "spam phishing legit" "win a free iPhone..."
export def classify [
    --multi                    # allow multiple labels (comma-separated output)
    ...labels: string          # candidate labels (at least 2)
] {
    let piped = $in
    if ($labels | length) < 2 {
        error make {msg: "classify: provide at least two labels"}
    }
    if $piped == null {
        error make {msg: "classify: pipe in the text to be classified"}
    }
    let src = if ($piped | describe) == "string" { $piped } else { $piped | to text }
    let label_list = $labels | str join ", "
    let mode = if $multi {
        "Return all labels that apply, comma-separated, in order of relevance."
    } else {
        "Return exactly one label — the single best fit."
    }
    let sys = $"You are a text classifier. Choose from these labels: ($label_list). ($mode) Output only the label\(s\) — nothing else. If none fit, return \"none\"."
    comma-call $sys $src
}

# Aggregate report: runs every relevant analyze command and returns the
# result as a single structured record. Deterministic analyses are always
# included; LLM-backed ones (sentiment, keywords, detect, readability) can
# be skipped with --no-llm to avoid API calls.
#
#   open article.md | report
#   open short.md | report --no-llm | to yaml
#   "..." | report --lang da --top 10
export def report [
    --no-llm                   # skip LLM-backed analyses
    --lang (-l): string = "en" # stopword set for freq/ngrams/ttr/hapax
    --top (-n): int = 15       # top-N for freq, ngrams and keywords
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text

    # Deterministic (fast, free)
    let s = $src | stats
    let l = $src | lix
    let t = $src | ttr --lang $lang
    let f = $src | freq --lang $lang --top $top
    let bg = $src | ngrams --n 2 --lang $lang --top $top
    let tg = $src | ngrams --n 3 --lang $lang --top ($top / 2 | math floor)
    let hx = $src | hapax --lang $lang
    let reps = $src | repeats --min-length 4 --min-count 2 --top 10
    let urls = $src | extract --kind url
    let emails = $src | extract --kind email
    let hashtags = $src | extract --kind hashtag
    let mentions = $src | extract --kind mention

    mut out = {
        meta: {
            generated: (date now | format date "%Y-%m-%d %H:%M")
            chars: $s.chars
            words: $s.words
            sentences: $s.sentences
            paragraphs: $s.paragraphs
            avg_word_length: $s.avg_word_length
        }
        readability: {
            lix: $l.lix
            interpretation: $l.interpretation
            avg_sentence_length: $l.avg_sentence_length
            long_word_pct: $l.long_word_pct
        }
        lexical: {
            types: $t.types
            tokens: $t.tokens
            ttr: $t.ttr
            hapax_count: ($hx | length)
            hapax_sample: ($hx | first 10)
        }
        top_words: $f
        top_bigrams: $bg
        top_trigrams: $tg
        repeated_phrases: $reps
        extracted: {
            urls: $urls
            emails: $emails
            hashtags: $hashtags
            mentions: $mentions
        }
    }

    if not $no_llm {
        # Each LLM call is wrapped individually: one transient failure must
        # not bring down the entire report. Failing fields get null.
        let lang_detected = try { $src | detect --name } catch { null }
        let sent = try { $src | sentiment --score } catch { null }
        let kw = try {
            $src | keywords --count $top | lines | each {|x| $x | str trim} | where ($it | is-not-empty)
        } catch { null }
        let read_parsed = try {
            $src | readability | lines | reduce --fold {} {|line, acc|
                let parts = $line | split column -c ": " key value
                if ($parts | is-not-empty) {
                    let p = $parts | first
                    $acc | upsert ($p.key | str trim) ($p.value? | default "" | str trim)
                } else { $acc }
            }
        } catch { null }
        $out = ($out | upsert llm {
            language: $lang_detected
            sentiment: $sent
            keywords: $kw
            readability: $read_parsed
        })
    }

    $out
}
