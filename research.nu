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
# Yderligere dependencies:
#   query web / query webpage-info  — nu_plugin_query, brugt af meta/links/feeds
#                                     og fetch --frontmatter til at læse HTML-
#                                     metadata, links og feeds.
#                                     cargo install nu_plugin_query && plugin add ~/.cargo/bin/nu_plugin_query
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
    --frontmatter              # prepend YAML frontmatter via query webpage-info
    --image-mode: string = "none"  # none | ansi | ansi-dither | kitty | sixel
    --wait: duration = 2sec    # kun --js: vent på JS-rendering
] {
    require reader

    mut reader_args = ["-o" "--image-mode" $image_mode]
    if $no_extract { $reader_args = ($reader_args | append "--no-readability") }

    # Når --frontmatter eller --js bruges, henter vi HTML separat så vi kan
    # videresende den til BÅDE reader og query webpage-info i ét trin.
    let need_html = $js or $frontmatter
    let html = if $need_html {
        if $js { http browse --wait $wait $url } else { http get $url }
    } else { null }

    let body = if $need_html {
        $html | ^reader ...$reader_args -
    } else {
        ^reader ...$reader_args $url
    }

    if $frontmatter {
        let info = $html | query webpage-info
        let fm = build-frontmatter $info $url
        $"($fm)\n\n($body)"
    } else {
        $body
    }
}

# Hjælper: byg YAML-frontmatter fra et webpage-info-record. Springer
# tomme/null felter over så frontmatter forbliver kompakt.
def build-frontmatter [info: record, url: string] {
    let sch = $info | get --optional schema_org | get --optional 0.value
    let meta = $info | get --optional meta
    let today = date now | format date "%Y-%m-%d"
    let entries = [
        {key: "title",       value: ($info | get --optional title)}
        {key: "source",      value: $url}
        {key: "captured",    value: $today}
        {key: "language",    value: ($info | get --optional language)}
        {key: "published",   value: (
            $sch | get --optional datePublished
            | default ($meta | get --optional "article:published_time")
        )}
        {key: "modified",    value: (
            $sch | get --optional dateModified
            | default ($meta | get --optional "article:modified_time")
        )}
        {key: "author",      value: ($sch | get --optional author | get --optional name)}
        {key: "description", value: ($info | get --optional description)}
    ]
    let body = $entries
        | where {|e| $e.value != null and $e.value != "" }
        | each {|e|
            let v = $e.value | into string | str replace --all "\"" "\\\""
            $"($e.key): \"($v)\""
        }
        | str join "\n"
    $"---\n($body)\n---"
}

# Strukturerede metadata for en URL via webpage-info. Returnerer et flat
# record med de mest nyttige felter: title, source, language, description,
# published, author, feed, plus rå opengraph og schema_org.
#
#   meta "https://example.com/article"
#   meta "https://example.com/article" --js
export def meta [
    url: string
    --js                       # brug headless browser
    --wait: duration = 2sec
] {
    let html = if $js {
        http browse --wait $wait $url
    } else {
        http get $url
    }
    let info = $html | query webpage-info
    let sch = $info | get --optional schema_org | get --optional 0.value
    let meta_tags = $info | get --optional meta
    {
        title: ($info | get --optional title)
        source: ($info | get --optional url | default $url)
        language: ($info | get --optional language)
        description: ($info | get --optional description)
        published: (
            $sch | get --optional datePublished
            | default ($meta_tags | get --optional "article:published_time")
        )
        modified: (
            $sch | get --optional dateModified
            | default ($meta_tags | get --optional "article:modified_time")
        )
        author: ($sch | get --optional author | get --optional name)
        feed: ($info | get --optional feed)
        opengraph: ($info | get --optional opengraph)
        schema_org: ($info | get --optional schema_org)
    }
}

# Udvinde outbound links fra en side. Returnerer en tabel med url og text.
# --external filtrerer til links der peger udenfor host'en.
#
#   links "https://example.com/article"
#   links "https://example.com/article" --external
export def links [
    url: string
    --external                 # kun links med fremmed host
    --js
    --wait: duration = 2sec
] {
    let html = if $js {
        http browse --wait $wait $url
    } else {
        http get $url
    }
    let all = $html | query webpage-info | get links
    if not $external { return $all }
    let host = try { $url | url parse | get host } catch { "" }
    $all | where {|l|
        let lhost = try { $l.url | url parse | get host } catch { "" }
        $lhost != "" and $lhost != $host
    }
}

# Udvinde RSS/Atom-feeds fra en side. webpage-info returnerer kun ét feed-felt;
# vi supplerer med <link rel="alternate" type="application/...+xml"> via query web
# så vi fanger sider der annoncerer flere feeds.
#
#   feeds "https://example.com"
export def feeds [
    url: string
    --js
    --wait: duration = 2sec
] {
    let html = if $js {
        http browse --wait $wait $url
    } else {
        http get $url
    }
    let primary = $html | query webpage-info | get --optional feed
    # query web med --attribute [a b] returnerer en liste-pr-element af
    # attribut-værdier i samme rækkefølge. Vi får [type, href] per <link>.
    let alternates = try {
        $html
            | query web --document --query 'link[rel="alternate"]' --attribute [type href]
            | where {|pair| (($pair | get 0? | default "") | str contains "xml") }
            | each {|pair| $pair | get 1? | default "" }
    } catch { [] }
    let primary_list = if $primary != null and $primary != "" { [$primary] } else { [] }
    let combined = ($primary_list | append $alternates)
        | where {|x| $x != null and $x != "" }
        | uniq
    # Gør relative URLer absolutte mod input-url
    let parsed = $url | url parse
    let origin = $parsed.scheme + "://" + $parsed.host
    $combined | each {|f|
        if ($f | str starts-with "http") { $f } else { (
            if ($f | str starts-with "/") { $origin + $f } else { $f }
        )}
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
