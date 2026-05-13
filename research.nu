# comma · research — hentning, destillation og bridge til generate.
#
# Persistens-laget er IWE (https://iwe.md). Comma rør ikke notebooks direkte
# — output piper brugeren selv til `iwe attach <key>` eller `iwe new <key>`
# med deres egen template-konfiguration.
#
# Dependencies (skal være i $PATH):
#   reader  — https://github.com/mrusme/reader (Mozilla Readability i Go)
#             go install github.com/mrusme/reader@latest
#
# Valgfri dependencies (kun til --js):
#   http browse  — nu_plugin_browse, kører headless Chromium for JS-renderet HTML
#                  cargo install nu_plugin_browse && plugin add ~/.cargo/bin/nu_plugin_browse
#                  Kræver chrome eller chromium installeret.
#
# Designvalg:
# - Alle kommandoer returnerer ren markdown på stdout. Persistens er brugerens valg.
# - reader's indbyggede HTTP er default — den klarer 80%+ af alm. blogs/artikler.
# - --js falder tilbage til http browse → reader (stdin) når reader's plain
#   HTTP rammer en JS-renderet shell-side.

use transform.nu sum

const PROVIDER = "gemini"
const MODEL    = "gemini-3.1-flash-lite-preview"
const TOOLS    = "none"

const PURITY_RULE = "Output requirements (strict):
- Return ONLY the resulting markdown.
- Do not wrap in code fences or extra quotes.
- Do not add a preamble, label, explanation, or trailing commentary.
- Follow any structural template given in the instructions exactly."

def require [cmd: string] {
    if (which $cmd | is-empty) {
        error make {msg: $"research: '($cmd)' ikke fundet i PATH. Installer det først."}
    }
}

def comma-input [piped: any, args: list<string>] {
    let joined = $args | str join " "
    if ($args | is-not-empty) { return $joined }
    if $piped == null {
        error make {msg: "research: pipe en streng ind eller giv tekst som argument"}
    }
    if ($piped | describe) == "string" { return $piped }
    if ($piped | describe) == "list<string>" { return ($piped | str join "\n") }
    error make {msg: $"research: pipe-input skal være tekst, ikke (($piped | describe)) — brug `open --raw fil`"}
}

def comma-cfg [] {
    $env | get COMMA_CFG? | default {
        provider: $PROVIDER
        model: $MODEL
        tools: $TOOLS
    }
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

# Hent en URL og ekstrahér hovedindholdet som markdown via reader (Mozilla
# Readability-port i Go). Reader har egen HTTP-klient, så vi behøver
# normalt ikke curl eller plugins.
#
#   fetch "https://example.com/artikel"
#   fetch "https://spa.com/page" --js          # JS-renderet: brug headless Chromium
#   fetch "https://eksempel.dk" --no-extract   # spring readability over (rå markdown)
#
# Typisk research-flow:
#   fetch <url> | iwe attach research-kaffe
#   fetch <url> --js | distill | iwe attach espresso-essentials
export def fetch [
    url: string                # URL der skal hentes
    --js                       # brug headless browser til JS-renderet sider
    --no-extract               # spring readability-ekstraktion over
    --image-mode: string = "none"  # none | ansi | ansi-dither | kitty | sixel
    --wait: duration = 2sec    # kun --js: vent på JS-rendering
] {
    require reader

    mut reader_args = ["-o" "--image-mode" $image_mode]
    if $no_extract { $reader_args = ($reader_args | append "--no-readability") }

    if $js {
        # http browse → stdin → reader
        let html = http browse --wait $wait $url
        $html | ^reader ...$reader_args -
    } else {
        # reader's egen HTTP
        ^reader ...$reader_args $url
    }
}

# Bearbejd rå capture (artikel, transskription, notat) til en struktureret
# studie-note med claims, citater, åbne spørgsmål og keywords. Output er
# markdown klar til `iwe attach <key>`.
#
#   fetch <url> | distill | iwe attach espresso-essentials
#   open --raw artikel.md | distill
export def distill [
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let sys = "You are a research analyst structuring raw material into a study note.

Output the note in exactly this markdown structure, with these exact headings:

## Claims
- <single declarative claim made by the source>
- <another claim>

## Quotes
> <verbatim quote from the source>
(<short context: who/where>)

> <another verbatim quote>
(<context>)

## Open questions
- <question raised but not answered by the source>
- <another question>

## Keywords
<5-15 comma-separated topical tags, lowercase>

Rules:
- Claims must be specific factual or evaluative assertions made by the source, not your summary.
- Quotes must be verbatim from the source. If there are no quotable passages, write `(none)` under Quotes.
- Open questions are gaps the source itself implies, not your curiosity.
- Match the source language for claims, quotes and questions. Keywords in source language too."
    comma-call $sys $src
}

# Ekstrahér verbatim citater fra en tekst der handler om et givet emne.
# Returnerer markdown blockquotes med kort kontekst.
#
#   open referat.md | cite "økonomisk vækst"
#   fetch <url> | cite "automatisering" --count 5
export def cite [
    topic: string              # emnet citaterne skal handle om
    --count (-n): int = 10     # max antal citater
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let sys = $"You are a quotation extractor. From the user's text, extract up to ($count) verbatim quotes that are directly about or directly relevant to the topic: \"($topic)\".

Output each quote in this exact format:
> <verbatim quote from the text>
\(<short context: speaker, section, page if visible — or \"—\" if none>\)

One quote per block, blank line between. No commentary, no paraphrasing, no numbering.
If no relevant quotes are found, return exactly: \"no relevant quotes\".
Match the source language."
    comma-call $sys $src
}

# Hent kontekst fra IWE for en given note-key og form den til et prompt-
# egnet baggrundsblok. Bridge-kommandoen mellem research/IWE og generate.
#
#   context espresso-essentials --depth 2 --shape brief
#
# Shapes:
#   background  — rå markdown fra `iwe retrieve` (default)
#   brief       — kører `sum --max 10` på output (kondenserer hierarkiet)
#   quotes-only — ekstrahér kun blockquotes (>) fra hierarkiet
export def context [
    key: string                # IWE note-key (slug)
    --depth (-d): int = 2      # inclusion-link depth (børn)
    --parent-context (-c): int = 1  # niveauer af forælder-kontekst (op)
    --max-chars: int = 16000   # hård cap (~4000 tokens) for at undgå prompt-overflow
    --shape: string = "background"  # background | brief | quotes-only
] {
    require iwe
    let raw = ^iwe retrieve -k $key -d $depth -c $parent_context -f markdown
    let shaped = match $shape {
        "background"  => $raw
        "brief"       => ($raw | sum --max 10)
        "quotes-only" => ($raw | lines | where ($it | str trim | str starts-with ">") | str join "\n")
        _ => (error make {msg: $"context: ukendt --shape '($shape)' \(brug background, brief, quotes-only\)"})
    }
    if ($shaped | str length) > $max_chars {
        ($shaped | str substring 0..$max_chars) + "\n\n[…trunkeret…]"
    } else {
        $shaped
    }
}
