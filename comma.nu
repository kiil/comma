# comma - opinionated sprog-overlay til yoke
#
# yolay.nu er en generel agent-REPL. comma.nu er det modsatte: et stramt
# sæt sprog-kommandoer der hver returnerer KUN den bearbejdede tekst.
# Ingen samtale-ctx, ingen værktøjer, ingen markdown-pynt — bare tekst
# ind, tekst ud, klar til pipe.
#
# Quick start:
#   overlay use comma.nu
#   "Hello, world" | tr da
#   "denne tekst er for lang og snørklet" | rw "kortere og klarere"
#   open notat.md | sum
#   "Jeg har set tre hunde igår" | proof
#   "vi skal mødes klokken to" | tone formal
#
# Designprincipper:
# - Hver kommando er stateless. Ingen $env.YO_CTX. Hver invokation er én tur.
# - Default tools=none. Sprogopgaver må ikke kalde shell/web/kode.
# - Output er ren tekst uden citationstegn, indledninger eller forklaringer.
# - Pipeline er førsteklasses input. Positionsargumenter er kun til korte
#   inline-strenge.
# - Mål-sprog accepterer både ISO-koder (da, en, fr) og navne (dansk, engelsk).

# --- Defaults ---

const PROVIDER = "gemini"
const MODEL    = "gemini-3.1-flash-lite-preview"
const TOOLS    = "none"

# Fælles regel der prependes til ALLE prompts. Stram, så modellen ikke
# tilføjer "Here is the translation:" eller markdown-citater.
const PURITY_RULE = "Output requirements (strict):
- Return ONLY the resulting text.
- Do not wrap in quotes, code fences, or markdown.
- Do not add a preamble, label, explanation, or trailing commentary.
- Preserve the source's paragraph breaks and line breaks.
- If the input is already in the requested target state, return it unchanged."

# --- Internal helpers ---

def comma-cfg [] {
    $env | get COMMA_CFG? | default {
        provider: $PROVIDER
        model: $MODEL
        tools: $TOOLS
    }
}

# Læs pipeline-input og evt. positionsargumenter, returnér én streng.
# Hvis begge er givet bruges positionsargumenter (typisk korte inline-tests).
def comma-input [piped: any, args: list<string>] {
    let joined = $args | str join " "
    if ($args | is-not-empty) { return $joined }
    if $piped == null {
        error make {msg: "comma: pipe en streng ind eller giv tekst som argument"}
    }
    if ($piped | describe) == "string" { return $piped }
    $piped | to text
}

# Kør yoke uden tools, opsaml assistant-tekst stille (ingen stream-render).
# System-prompten injiceres som en system-record forrest i JSONL-stdin
# (samme mønster som yo/mod.nu bruger).
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

# --- Commands ---

# Oversæt tekst til et mål-sprog.
#
#   "Hello world" | tr da
#   "Hej" | tr --formal en
#   tr fransk "god morgen"
export def tr [
    target: string             # mål-sprog: ISO-kode (da, en, fr, ...) eller navn (dansk, engelsk)
    --from: string             # kilde-sprog (auto hvis udeladt)
    --formal                   # brug formel/De-form hvis sproget skelner
    --casual                   # brug uformel/du-form
    ...text: string            # tekst inline (ellers via pipe)
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

# Omskriv tekst efter en kort instruktion. Bevarer kerneindhold.
#
#   "lang snørklet sætning" | rw "kortere"
#   open udkast.md | rw "mere direkte og aktiv stemme"
#   rw "som en LinkedIn-post" "vi har lanceret et nyt produkt..."
export def rw [
    instruction: string        # hvordan teksten skal omskrives
    ...text: string            # tekst inline (ellers via pipe)
] {
    let piped = $in
    let src = comma-input $piped $text
    let sys = $"You are a precise editor. Rewrite the user's text according to this instruction: \"($instruction)\". Keep the original meaning and any concrete facts intact. Match the source language unless the instruction explicitly asks for translation."
    comma-call $sys $src
}

# Opsummer tekst. Default: tæt prosa-resumé, samme sprog som kilden.
#
#   open artikel.md | sum
#   sum --bullets "lang tekst..."
#   sum --max 3 "..."          # max 3 sætninger
export def sum [
    --bullets (-b)             # output som punktliste i stedet for prosa
    --max (-m): int            # max antal sætninger/punkter (default: model-bestemt, typisk 3-5)
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

# Korrekturlæsning: ret stavning, grammatik, tegnsætning. Bevar stemme,
# struktur og ordvalg. Returnerer KUN den rettede tekst.
#
#   "Jeg har set tre hunde igår" | proof
#   open udkast.md | proof | save -f udkast.md
export def proof [
    --strict (-s)              # ret også klodset ordstilling og uklarheder
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

# Skift tone på teksten uden at ændre indhold.
#
#   "vi skal mødes kl 14" | tone formal
#   "Dear Sir/Madam, ..." | tone casual
#   tone executive "her er en lang teknisk forklaring..."
#
# Kendte stilarter: formal, casual, executive, friendly, neutral, direct,
# diplomatic. Andre værdier sendes ordret videre til modellen.
export def tone [
    style: string              # tone-navn (se ovenfor) eller fri beskrivelse
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

# Vis nuværende config og en kort liste over kommandoer.
export def status [] {
    let c = comma-cfg
    print $"(ansi cyan_bold)comma(ansi reset) · ($c.provider)/($c.model) · tools: ($c.tools)"
    print $"(ansi attr_dimmed)kommandoer: tr · rw · sum · proof · tone(ansi reset)"
}

# Skift model/provider for resten af sessionen.
#
#   model claude-sonnet-4-6 --provider anthropic
#   model gpt-4o --provider openai
export def --env model [
    name: string
    --provider: string
] {
    let current = comma-cfg
    let updated = if $provider != null {
        $current | merge {model: $name, provider: $provider}
    } else {
        $current | merge {model: $name}
    }
    $env.COMMA_CFG = $updated
    print $"(ansi attr_dimmed)now: ($updated.provider)/($updated.model)(ansi reset)"
}

# --- Aliases (komma-præfiks ligesom yolay) ---

export alias ,t  = tr
export alias ,r  = rw
export alias ,s  = sum
export alias ,p  = proof
export alias ,o  = tone
export alias ,?  = status
export alias ,m  = model

# --- Overlay init ---

export-env {
    $env.COMMA_CFG = $env | get COMMA_CFG? | default {
        provider: $PROVIDER
        model: $MODEL
        tools: $TOOLS
    }
    print $"(ansi cyan_bold)comma overlay(ansi reset) loaded · ($env.COMMA_CFG.provider)/($env.COMMA_CFG.model) · sprog: (ansi yellow_bold)tr rw sum proof tone(ansi reset)"
}
