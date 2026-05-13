# comma · validate — verification against reality.
#
# Where analyze inspects text as text (statistics, classification,
# readability), validate asks: is this true? That requires lookups,
# sources, and stronger reasoning than the other LLM calls.
#
# Three commands:
#   factcheck  — verify factual claims against web sources
#   quotes     — verify quote wording and attribution
#   claims     — extract discrete claims (preprocessing step)
#
# The default model is stronger than the rest of comma and has tools
# enabled. Override via $env.COMMA_VALIDATE_CFG.

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
        error make {msg: "validate: pipe a string in or pass text as an argument"}
    }
    if ($piped | describe) == "string" { return $piped }
    $piped | to text
}

def comma-call [system: string, user: string] {
    # Validate ignores $env.COMMA_CFG and uses its own setup. Tools are ON
    # by default — without web_search, factcheck/quotes would just
    # hallucinate citations.
    let c = $env | get COMMA_VALIDATE_CFG? | default {
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

# Fact-check claims in a text. Looks them up via web_search.
#
#   open article.md | factcheck
#   "Denmark has 12 million inhabitants" | factcheck
#   factcheck --strict "..."       # flag even small inaccuracies
export def factcheck [
    --strict (-s)              # be strict about numbers, dates, quotations
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

# Verify quotations: are they accurate, and attributed to the right
# person/source?
#
#   open speech.md | quotes
#   "As Einstein said: 'God does not play dice'" | quotes
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

# Extract discrete claims from a text — without assessing them.
# Useful as preprocessing for factcheck or for debate preparation.
# Tools are not strictly required for this command, but we use the same
# config for consistency.
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
