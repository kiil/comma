# comma · generate — kommandoer der producerer ny tekst ud fra et input.
#
# I modsætning til transform.nu, hvor inputtet ER teksten der bearbejdes,
# bruges inputtet her som brief, emne eller skelet for noget nyt der skrives.
#
# Generate-kommandoerne kan trække kontekst ind fra IWE via --notes <key>
# (forudsætter at research.nu's context-bridge er aktiv). Modellen får
# noterne som faktuel grund-sandhed, ikke som tekst der skal omskrives.

use research.nu context

const PROVIDER = "gemini"
const MODEL    = "gemini-3.1-flash-lite-preview"
const TOOLS    = "none"

const PURITY_RULE = "Output requirements (strict):
- Return ONLY the resulting text.
- Do not wrap in quotes, code fences, or markdown.
- Do not add a preamble, label, explanation, or trailing commentary.
- Preserve any requested formatting (e.g. one item per line for lists).
- No meta-commentary about your own process."

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
        error make {msg: "comma: pipe en streng ind eller giv tekst som argument"}
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
    $records
        | where { $in | get role? | $in == "assistant" }
        | last
        | get content
        | each {|b| if ($b | get type?) == "text" { $b.text } else { null } }
        | compact
        | str join ""
        | str trim
}

# Hjælper: hvis --notes er angivet, henter vi IWE-kontekst via research-
# bridgen og pakker den som baggrunds-blok foran selve system-prompten.
def with-notes [sys: string, notes: any, depth: int, shape: string] {
    if $notes == null { return $sys }
    let ctx = context $notes --depth $depth --shape $shape
    $"Research context follows. Use these notes as factual ground truth — do not invent facts beyond them, but feel free to synthesize across them.

---
($ctx)
---

($sys)"
}

# Skriv et udkast ud fra en kort brief.
#
#   "blogpost om kaffe-extraction" | draft
#   draft --words 200 "produktbeskrivelse for støvler i regnvejr"
#   "blogpost om espresso" | draft --notes espresso-essentials
export def draft [
    --words (-w): int          # ca. antal ord (model-bestemt hvis udeladt)
    --lang (-l): string        # output-sprog (default: samme som briefen)
    --notes: string            # IWE note-key — hentes som baggrund via context
    --notes-depth: int = 2     # inclusion-link depth ned i hierarkiet
    --notes-shape: string = "background"  # background | brief | quotes-only
    ...brief: string           # brief inline (ellers via pipe)
] {
    let piped = $in
    let src = comma-input $piped $brief
    let len = if $words != null { $" Aim for roughly ($words) words." } else { "" }
    let lang = if $lang != null { $" Write in ($lang)." } else { " Match the language of the brief." }
    let sys = $"You are a versatile writer. Produce a complete draft that fulfills the following brief. Write the actual text the user would publish or send — not an outline, not options, not a description of what you would write.($lang)($len)"
    let sys_final = with-notes $sys $notes $notes_depth $notes_shape
    comma-call $sys_final $src
}

# Udvid kort-noter, bullets eller stikord til sammenhængende prosa.
#
#   "- mødte Anna\n- talte om Q3\n- aftalt opfølgning fredag" | expand
#   expand --style email "tak for mødet, send slides, book opfølgning"
#   "intro om kaffe" | expand --notes espresso-essentials
export def expand [
    --style (-s): string       # f.eks. "email", "rapportafsnit", "blogpost"
    --notes: string            # IWE note-key — hentes som baggrund
    --notes-depth: int = 2
    --notes-shape: string = "background"
    ...bullets: string         # bullets/stikord inline (ellers via pipe)
] {
    let piped = $in
    let src = comma-input $piped $bullets
    let style = if $style != null { $" Render it as a ($style)." } else { " Use natural connecting prose." }
    let sys = $"You are an editor turning shorthand notes into finished prose. Expand the user's bullets or fragments into a connected, flowing text that covers exactly the points listed — no new facts, no invented details.($style) Match the source language."
    let sys_final = with-notes $sys $notes $notes_depth $notes_shape
    comma-call $sys_final $src
}

# Foreslå titler/overskrifter til en tekst.
#
#   open artikel.md | title
#   title --count 10 --style clickbait "lang tekst..."
export def title [
    --count (-n): int = 5      # antal forslag
    --style: string            # f.eks. "neutral", "clickbait", "akademisk", "SEO"
    --notes: string            # IWE note-key — hentes som baggrund
    --notes-depth: int = 2
    --notes-shape: string = "background"
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let style = if $style != null { $" Style: ($style)." } else { "" }
    let sys = $"You are a headline writer. Propose ($count) distinct title candidates for the user's text. One title per line, no numbering, no bullets, no quotes. Each title should stand on its own.($style) Match the source language."
    let sys_final = with-notes $sys $notes $notes_depth $notes_shape
    comma-call $sys_final $src
}

# Brainstorm idéer omkring et emne.
#
#   "navne til en ny kaffe-bar i Aarhus" | ideas
#   ideas --count 20 "features til en CLI-todo-app"
#   "vinklinger på en historie om kaffe" | ideas --notes espresso-essentials
export def ideas [
    --count (-n): int = 10     # antal idéer
    --notes: string            # IWE note-key — hentes som baggrund/inspiration
    --notes-depth: int = 2
    --notes-shape: string = "background"
    ...topic: string
] {
    let piped = $in
    let src = comma-input $piped $topic
    let sys = $"You are a creative collaborator. Generate ($count) distinct, concrete ideas for the user's topic. One idea per line, no numbering, no bullets, no explanations — just the ideas themselves. Favor specificity and variety over safety. Match the source language."
    let sys_final = with-notes $sys $notes $notes_depth $notes_shape
    comma-call $sys_final $src
}

# Generér spørgsmål til en tekst eller et emne (interview, FAQ, læring).
#
#   open whitepaper.md | ask
#   ask --count 8 --kind interview "ny CTO der starter på mandag"
#   "hvad mangler vi i forskningen?" | ask --notes espresso-essentials --kind socratic
export def ask [
    --count (-n): int = 8      # antal spørgsmål
    --kind (-k): string = "open"  # "open" | "faq" | "interview" | "socratic"
    --notes: string            # IWE note-key — hentes som baggrund
    --notes-depth: int = 2
    --notes-shape: string = "background"
    ...source: string
] {
    let piped = $in
    let src = comma-input $piped $source
    let kind = match $kind {
        "faq"       => "frequently-asked, practical questions a reader would have"
        "interview" => "open-ended interview questions that invite a thoughtful answer"
        "socratic"  => "socratic questions that probe assumptions and push deeper"
        _           => "diverse, open-ended questions that explore the material"
    }
    let sys = $"You are a thoughtful interviewer. Generate ($count) ($kind) about the user's text or topic. One question per line, no numbering, no bullets. Match the source language."
    let sys_final = with-notes $sys $notes $notes_depth $notes_shape
    comma-call $sys_final $src
}
