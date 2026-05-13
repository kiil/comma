# comma · analyze — kommandoer der inspicerer tekst og returnerer indsigt.
#
# Output er stadig ren tekst (for pipe-venlighed), men det er en
# beskrivelse AF inputtet — ikke en omskrivning af det.
#
# I modsætning til transform/generate har analyze tools slået TIL by default
# (web_search til opslag mod virkeligheden, nu til lokale lookups). Det er
# nødvendigt for kommandoer som factcheck og quotes der ellers bare ville
# hallucinere. Overstyres via $env.COMMA_CFG.tools om nødvendigt.

const PROVIDER = "gemini"
const MODEL    = "gemini-3-pro-preview"
const TOOLS    = "web_search,nu"

const PURITY_RULE = "Output requirements (strict):
- Return ONLY the analysis result in the exact format requested.
- Do not wrap in quotes, code fences, or markdown.
- Do not add a preamble, label, explanation, or trailing commentary.
- No hedging (\"it seems\", \"likely\") unless explicitly asked for confidence."

def comma-input [piped: any, args: list<string>] {
    let joined = $args | str join " "
    if ($args | is-not-empty) { return $joined }
    if $piped == null {
        error make {msg: "comma: pipe en streng ind eller giv tekst som argument"}
    }
    if ($piped | describe) == "string" { return $piped }
    $piped | to text
}

def comma-call [system: string, user: string] {
    # Analyze ignorerer $env.COMMA_CFG og bruger ALTID sit eget setup:
    # gemini-3-pro-preview med web_search+nu. Ellers ville mod.nu's overlay-init
    # (tools=none, flash-lite-modellen) gøre factcheck/quotes til ren
    # hallucination. Overstyres bevidst via $env.COMMA_ANALYZE_CFG.
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
    $records
        | where { $in | get role? | $in == "assistant" }
        | last
        | get content
        | each {|b| if ($b | get type?) == "text" { $b.text } else { null } }
        | compact
        | str join ""
        | str trim
}

# Deterministiske tællinger over en tekst. Bruger nu's str stats som basis
# og tilføjer sætnings-, paragraf- og ordstatistik. Ingen LLM involveret —
# samme tekst giver altid samme tal.
#
#   "Hello world. This is a test." | stats
#   open artikel.md | stats --verbose
export def stats [
    --verbose (-v)             # tilføj top-ord-frekvens og ordlængde-fordeling
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

# Ord-frekvens-analyse. Deterministisk: downcase → split words → stopword-
# filter → uniq -c → sort. Mønster fra kiils.dk's bible-analyse i nu.
#
#   open bog.txt | freq
#   open artikel.md | freq --lang da --top 20
#
# Returnerer en tabel med kolonnerne value og count, sorteret faldende.
# For meget store korpora kan polars-versionen i artiklen være ~10x hurtigere
# — den er ikke inkluderet her for at undgå plugin-afhængighed.
export def freq [
    --lang (-l): string = "en" # stopword-sæt: en | da | none
    --top (-n): int = 50       # antal mest hyppige ord (0 = alle)
    --no-stop                  # spring stopword-filter helt over
    --stop: list<string>       # brugerdefineret stopword-liste (overskriver --lang)
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

# Indbyggede stopword-sæt. Holdt korte og pragmatiske —
# brugere kan altid sende deres egen liste via --stop.
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
        _ => (error make {msg: $"freq: ukendt --lang '($lang)' (brug en, da eller none)"})
    }
}

# Hjælper: tjek om en streng er en eksisterende filsti, sikkert (inline-tekst
# kan indeholde tegn der får path exists til at fejle).
def is-file [s: string]: nothing -> bool {
    if ($s | str length) > 4096 { return false }
    if ($s | str contains "\n") { return false }
    try { $s | path exists } catch { false }
}

# Hjælper: indlæs tekst — enten direkte eller fra en filsti.
def load-text [s: string]: nothing -> string {
    if (is-file $s) { open --raw $s } else { $s }
}

# N-gram-frekvens. Default: bigrams. Stopword-filtrering kører FØR
# vinduet, så grams ikke krydser fjernede ord.
#
#   open bog.txt | ngrams --n 2 --top 20
#   "the quick brown fox jumps over the lazy dog" | ngrams --n 3
export def ngrams [
    --n: int = 2               # vinduesstørrelse (2 = bigrams, 3 = trigrams)
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

# Keyword-in-context (KWIC). For hvert forekomst af et søgeord vises
# et antal ord før og efter — klassisk concordance.
#
#   open bog.txt | kwic gud --window 6
export def kwic [
    keyword: string            # ordet at finde
    --window (-w): int = 5     # antal ord på hver side
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

# Lix-læsbarhedstal (skandinavisk standard). Rent aritmetisk.
# Lix = ord/sætninger + (lange_ord × 100 / ord), hvor "lang" = >6 bogstaver.
#
#   open udkast.md | lix
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
        error make {msg: "lix: ingen sætninger eller ord at måle"}
    }
    let long = $words | where {|w| ($w | str length) > 6} | length
    let asl = ($n_words / $n_sent)
    let lwp = ($long * 100 / $n_words)
    let lix = ($asl + $lwp)
    let bands = [
        [threshold, label];
        [25,    "meget let (børnebog)"]
        [35,    "let (skønlitteratur, ugeblade)"]
        [45,    "middel (dagblade)"]
        [55,    "svær (saglig prosa)"]
        [99999, "meget svær (faglitteratur, lovtekst)"]
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

# Find gentagne fraser i en tekst — fanger utilsigtet duplikeret prosa.
#
#   open udkast.md | repeats
#   open lang.md | repeats --min-length 5 --min-count 3
export def repeats [
    --min-length (-l): int = 4 # minimum ord per frase
    --min-count (-c): int = 2  # minimum antal forekomster
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

# Sammenlign to tekster — distinctive ord for hver. Bruger smoothed
# log-odds: positiv score = ordet er relativt hyppigere i A, negativ = i B.
# Andet input kan være tekst-streng eller filsti.
#
#   open mit.md | compare reference.md
#   "..." | compare "..." --top 20 --lang da
export def compare [
    other: string              # tekst eller filsti
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
        error make {msg: "compare: en af teksterne er tom"}
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

# Hapax legomena — ord der kun forekommer én gang. Stylometrisk signal.
#
#   open novelle.md | hapax
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

# Type-token-ratio (leksikalsk variation). 1.0 = hvert ord er unikt.
#
#   open udkast.md | ttr
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
        error make {msg: "ttr: ingen ord at måle"}
    }
    let types = $words | uniq | length
    {
        types: $types
        tokens: $tokens
        ttr: ($types / $tokens | math round --precision 3)
    }
}

# Jaccard-lighed mellem to tekster via k-shingles (k ord ad gangen).
# Returnerer score i [0,1] — højere = mere ens.
#
#   open kapitel1.md | similar kapitel2.md --k 4
export def similar [
    other: string              # tekst eller filsti
    --k: int = 3               # shingle-størrelse (ord)
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

# Split tekst i sætninger som en liste — komponerer godt med andre kommandoer.
#
#   open artikel.md | sentences | each {|s| $s | lix}
export def sentences [
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    $src | split row -r '[.!?]+\s+'
        | each {|s| $s | str trim}
        | where ($it | is-not-empty)
}

# Split tekst i paragraffer som en liste.
#
#   open bog.md | paragraphs | each {|p| $p | stats}
export def paragraphs [
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    $src | split row -r '\n\s*\n'
        | each {|p| $p | str trim}
        | where ($it | is-not-empty)
}

# Regex-udtrækning af URLs, emails, hashtags eller @-mentions.
#
#   open notes.md | extract --kind url
#   "tweet @somebody om #nushell" | extract --kind hashtag
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
        _ => (error make {msg: $"extract: ukendt --kind '($kind)' (brug url, email, hashtag eller mention)"})
    }
    $src | parse --regex $pattern | get m | uniq
}

# Detektér sproget af en tekst. Returnerer ISO-639-1-kode by default.
#
#   "god morgen" | detect           # => da
#   "god morgen" | detect --name    # => Danish
export def detect [
    --name                     # returnér engelsk sprognavn i stedet for ISO-kode
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

# Sentiment-analyse. Default: ét ord (positive/neutral/negative).
#
#   "elsker det her produkt" | sentiment           # => positive
#   "elsker det her produkt" | sentiment --score   # => positive (0.85)
export def sentiment [
    --score                    # tilføj numerisk score i [-1, 1]
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

# Udtræk nøgleord / nøglefraser fra en tekst.
#
#   open artikel.md | keywords
#   keywords --count 5 "lang tekst..."
export def keywords [
    --count (-n): int = 10     # antal nøgleord
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let sys = $"You are a keyword extractor. Extract the ($count) most important keywords or short key phrases from the user's text. One per line, lowercase unless the term is a proper noun, no numbering, no bullets, no explanations. Order by importance. Match the source language."
    comma-call $sys $src
}

# Udtræk navngivne entiteter (personer, steder, organisationer, datoer, beløb).
#
#   open referat.md | entities
#   entities --kind person "..."
export def entities [
    --kind (-k): string        # filtrér: person | place | org | date | money
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

# Vurdér læsbarhed (sværhedsgrad, målgruppe, gennemsnitlig sætningslængde).
#
#   open udkast.md | readability
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

# Fact-check påstande i en tekst. Slår op via web_search.
#
#   open artikel.md | factcheck
#   "Danmark har 12 millioner indbyggere" | factcheck
#   factcheck --strict "..."       # markér selv små unøjagtigheder
export def factcheck [
    --strict (-s)              # vær striks ved tal, datoer, citater
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let scope = if $strict {
        "Flag every factual claim, including small numerical or chronological inaccuracies."
    } else {
        "Focus on substantive claims that would mislead a reader. Skip trivial paraphrasing."
    }
    let sys = $"You are a fact-checker with web_search. For each non-trivial factual claim in the user's text, verify it against authoritative sources via web_search. ($scope)

Output one line per claim, in this exact format:
[<verdict>] <claim> — <evidence or correction> (<source url or domain>)

Verdicts: TRUE, FALSE, MISLEADING, UNVERIFIABLE.
Order: most consequential errors first.
If every claim checks out, return exactly the single line: \"OK — no errors found\".
Match the source language for claim text; keep verdict labels in English."
    comma-call $sys $src
}

# Verificér citater: er de korrekte, og er de tilskrevet rette person/kilde?
#
#   open tale.md | quotes
#   "Som Einstein sagde: 'Gud spiller ikke terninger'" | quotes
export def quotes [
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let sys = "You are a quotation verifier with web_search. Find every quoted passage in the user's text (anything in quotation marks attributed to a person, work, or source). For each one, verify via web_search:
1. Is the wording accurate?
2. Is the attribution correct?
3. Is the context appropriate (not a misattributed paraphrase, not stripped of meaning)?

Output one block per quote separated by a blank line, in this exact format:
quote: \"<the quote as it appears>\"
attribution: <as given in the text>
verdict: <one of: VERIFIED, MISQUOTED, MISATTRIBUTED, FABRICATED, UNVERIFIABLE>
correction: <the accurate wording and source, or \"—\" if verdict is VERIFIED>
source: <url or canonical reference>

If no quotes are present, return exactly: \"no quotes found\"."
    comma-call $sys $src
}

# Udtræk diskrete påstande fra en tekst — uden at vurdere dem.
# Nyttig som forarbejde til factcheck eller debat-forberedelse.
#
#   open essay.md | claims
export def claims [
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let sys = "You are a claim extractor. List every distinct factual or evaluative claim the user's text makes — what the text asserts to be true, not background or framing. One claim per line, rephrased as a standalone declarative sentence (so it can be evaluated out of context). No numbering, no bullets, no hedging. Match the source language."
    comma-call $sys $src
}

# Klassificér en tekst i én af de angivne kategorier.
#
#   "kan I sende mig en faktura?" | classify support sales billing
#   classify --multi "spam phishing legit" "vind en gratis iPhone..."
export def classify [
    --multi                    # tillad flere labels (komma-separeret output)
    ...labels: string          # mulige labels (mindst 2)
] {
    let piped = $in
    if ($labels | length) < 2 {
        error make {msg: "classify: angiv mindst to labels"}
    }
    if $piped == null {
        error make {msg: "classify: pipe teksten der skal klassificeres ind"}
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

# Samlet rapport: kører alle relevante analyze-kommandoer og returnerer
# resultatet som ét struktureret record. Deterministiske analyser inkluderes
# altid; LLM-baserede (sentiment, keywords, detect, readability) kan slås
# fra med --no-llm for at undgå API-kald.
#
#   open artikel.md | report
#   open kort.md | report --no-llm | to yaml
#   "..." | report --lang da --top 10
export def report [
    --no-llm                   # spring LLM-baserede analyser over
    --lang (-l): string = "en" # stopword-sæt til freq/ngrams/ttr/hapax
    --top (-n): int = 15       # top-N for freq, ngrams og keywords
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text

    # Deterministisk (hurtigt, gratis)
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
        let lang_detected = $src | detect --name
        let sent = $src | sentiment --score
        let kw = $src | keywords --count $top | lines | each {|x| $x | str trim} | where ($it | is-not-empty)
        let read = $src | readability
        let read_parsed = $read | lines | reduce --fold {} {|line, acc|
            let parts = $line | split column -c ": " key value
            if ($parts | is-not-empty) {
                let p = $parts | first
                $acc | upsert ($p.key | str trim) ($p.value? | default "" | str trim)
            } else { $acc }
        }
        $out = ($out | upsert llm {
            language: $lang_detected
            sentiment: $sent
            keywords: $kw
            readability: $read_parsed
        })
    }

    $out
}
