# comma · transform — commands that rewrite existing text.
#
# Each command takes text in (via pipe or argument) and returns a rewritten
# version of that text. No conversation context, no tools.

const PROVIDER = "gemini"
const MODEL    = "gemini-3.1-flash-lite-preview"
const TOOLS    = "none"

const PURITY_RULE = "Output requirements (strict):
- Return ONLY the resulting text.
- Do not wrap in quotes, code fences, or markdown.
- Do not add a preamble, label, explanation, or trailing commentary.
- Preserve the source's paragraph breaks and line breaks.
- If the input is already in the requested target state, return it unchanged."

def comma-cfg [] {
    $env | get COMMA_CFG? | default {
        provider: $PROVIDER
        model: $MODEL
        tools: $TOOLS
    }
}

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
    let c = comma-cfg
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

# Translate text to a target language.
#
#   "Hello world" | tr da
#   "Hej" | tr --formal en
#   tr french "good morning"
export def tr [
    target: string             # target language: ISO code (da, en, fr, ...) or name (Danish, English)
    --from: string             # source language (auto-detected if omitted)
    --formal                   # use the formal register where the language distinguishes
    --casual                   # use the informal register
    ...text: string            # text inline (or via pipe)
] {
    let piped = $in
    let src = comma-input $piped $text
    let from_clause = if $from != null { $"from ($from) " } else { "" }
    let register = if $formal {
        " Use a formal register (e.g. De-form in Danish, Sie-form in German, vous in French)."
    } else if $casual {
        " Use an informal/casual register (e.g. du-form in Danish, du-form in German, tu in French)."
    } else { "" }
    let sys = $"You are a professional literary translator. Translate the user's text ($from_clause)into ($target). Preserve meaning, tone, register, formatting, and proper nouns. Idioms become natural equivalents in the target language, not literal translations.($register)"
    comma-call $sys $src
}

# Rewrite text according to a short instruction. Preserves core content.
#
#   "long convoluted sentence" | rw "shorter"
#   open draft.md | rw "more direct, active voice"
#   rw "as a LinkedIn post" "we just launched a new product..."
export def rw [
    instruction: string        # how the text should be rewritten
    ...text: string            # text inline (or via pipe)
] {
    let piped = $in
    let src = comma-input $piped $text
    let sys = $"You are a precise editor. Rewrite the user's text according to this instruction: \"($instruction)\". Keep the original meaning and any concrete facts intact. Match the source language unless the instruction explicitly asks for translation."
    comma-call $sys $src
}

# Summarize text. Default: dense prose summary, same language as the source.
#
#   open article.md | sum
#   sum --bullets "long text..."
#   sum --max 3 "..."          # max 3 sentences
export def sum [
    --bullets (-b)             # output as bullet list instead of prose
    --max (-m): int            # max number of sentences/bullets (default: model-decided, typically 3-5)
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let format = if $bullets { "a tight bullet list (one fact per bullet, no sub-bullets)" } else { "dense prose (no headings, no bullets)" }
    let unit = if $bullets { "bullets" } else { "sentences" }
    let limit = if $max != null { $" Limit the output to at most ($max) ($unit)." } else { "" }
    let sys = $"You are a senior analyst writing executive summaries. Summarize the user's text as ($format). Keep the source language. Prioritize concrete facts, decisions, numbers and named entities over generalities. Do not editorialize.($limit)"
    comma-call $sys $src
}

# Proofreading: fix spelling, grammar, punctuation. Preserve voice,
# structure and word choice. Returns ONLY the corrected text.
#
#   "Jeg har set tre hunde igår" | proof
#   open draft.md | proof | save -f draft.md
export def proof [
    --strict (-s)              # also fix awkward word order and unclear phrasing
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let scope = if $strict {
        "spelling, grammar, punctuation, awkward phrasing, and unclear constructions"
    } else {
        "spelling, grammar, and punctuation only — leave style, voice and word choice alone"
    }
    let sys = $"You are a meticulous proofreader. Correct ($scope) in the user's text. Preserve the author's voice, paragraph structure, line breaks, and any deliberate stylistic choices. Match the source language."
    comma-call $sys $src
}

# Shift the tone of the text without changing content.
#
#   "we should meet at 2" | tone formal
#   "Dear Sir/Madam, ..." | tone casual
#   tone executive "here is a long technical explanation..."
#
# Known styles: formal, casual, executive, friendly, neutral, direct,
# diplomatic. Any other value is passed verbatim to the model.
export def tone [
    style: string              # tone name (see above) or freeform description
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let guidance = match $style {
        "formal" => "formal, polite, no contractions, full sentences"
        "casual" => "casual, conversational, contractions allowed, light"
        "executive" => "executive: terse, decision-oriented, lead with the point, no fluff"
        "friendly" => "warm and friendly without being saccharine"
        "neutral" => "neutral and factual, no emotional coloring"
        "direct" => "direct and unhedged, no softeners or qualifiers"
        "diplomatic" => "diplomatic: acknowledge multiple perspectives, soften disagreement"
        _ => $"the following style: ($style)"
    }
    let sys = $"You are a register specialist. Rewrite the user's text in ($guidance). Keep the meaning, facts, and approximate length unchanged. Match the source language."
    comma-call $sys $src
}
