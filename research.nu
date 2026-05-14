# comma · research — fetching, distillation, and the bridge to generate.
#
# The persistence layer is IWE (https://iwe.md). comma does not touch
# notebooks directly — the user pipes output to `iwe new "<Title>"`
# (which slugifies the title into the filename) and optionally chains
# `iwe attach -k <slug> --to <action>` to link the new note into a
# configured target (daily log, inbox, …) defined in .iwe/config.toml.
#
# Dependencies (must be on $PATH):
#   reader  — https://github.com/mrusme/reader (Mozilla Readability in Go)
#             go install github.com/mrusme/reader@latest
#
# Additional dependencies:
#   query web / query webpage-info  — nu_plugin_query, used by meta/links/feeds
#                                     and fetch --frontmatter to read HTML
#                                     metadata, links and feeds.
#                                     cargo install nu_plugin_query && plugin add ~/.cargo/bin/nu_plugin_query
#
# Optional dependencies (only for --js):
#   http browse  — nu_plugin_browse, runs headless Chromium for JS-rendered HTML
#                  cargo install nu_plugin_browse && plugin add ~/.cargo/bin/nu_plugin_browse
#                  Requires Chrome or Chromium to be installed.
#
# Design choices:
# - All commands return plain markdown on stdout. Persistence is the user's call.
# - reader's built-in HTTP is the default — it handles 80%+ of normal blogs/articles.
# - --js falls back to http browse → reader (stdin) when reader's plain HTTP
#   gets a JS-rendered shell page.

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
        error make {msg: $"research: '($cmd)' not found in PATH. Install it first."}
    }
}

def comma-input [piped: any, args: list<string>] {
    let joined = $args | str join " "
    if ($args | is-not-empty) { return $joined }
    if $piped == null {
        error make {msg: "research: pipe a string in or pass text as an argument"}
    }
    if ($piped | describe) == "string" { return $piped }
    if ($piped | describe) == "list<string>" { return ($piped | str join "\n") }
    error make {msg: $"research: pipe input must be text, not (($piped | describe)) — use `open --raw file`"}
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

# Fetch a URL and extract its main content as markdown via reader (the
# Mozilla Readability port in Go). reader has its own HTTP client, so we
# normally don't need curl or plugins.
#
#   fetch "https://example.com/article"
#   fetch "https://spa.com/page" --js          # JS-rendered: use headless Chromium
#   fetch "https://example.com" --no-extract   # skip readability (raw markdown)
#
# Typical research flow:
#   fetch <url> | iwe new "Coffee article"
#   fetch <url> --js | distill | iwe new "Espresso essentials"
export def fetch [
    url: string                # URL to fetch
    --js                       # use headless browser for JS-rendered pages
    --no-extract               # skip readability extraction
    --frontmatter              # prepend YAML frontmatter via query webpage-info
    --image-mode: string = "none"  # none | ansi | ansi-dither | kitty | sixel
    --wait: duration = 2sec    # only with --js: JS-rendering wait time
] {
    require reader

    mut reader_args = ["-o" "--image-mode" $image_mode]
    if $no_extract { $reader_args = ($reader_args | append "--no-readability") }

    # When --frontmatter or --js is used, we fetch HTML separately so we can
    # forward it to BOTH reader and query webpage-info in a single call.
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

# Helper: build YAML frontmatter from a webpage-info record. Empty/null
# fields are skipped so the frontmatter stays compact.
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

# Structured metadata for a URL via webpage-info. Returns a flat record
# with the most useful fields: title, source, language, description,
# published, modified, author, feed, plus raw opengraph and schema_org.
#
#   meta "https://example.com/article"
#   meta "https://example.com/article" --js
export def meta [
    url: string
    --js                       # use headless browser
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

# Extract outbound links from a page. Returns a table with url and text.
# --external filters to links pointing outside the page's host.
#
#   links "https://example.com/article"
#   links "https://example.com/article" --external
export def links [
    url: string
    --external                 # only links with a foreign host
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

# Extract RSS/Atom feeds from a page. webpage-info returns only a single
# feed field; we supplement with <link rel="alternate" type="application/...+xml">
# via query web so we catch pages that advertise multiple feeds.
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
    # `query web --attribute [a b]` returns a list-per-element of attribute
    # values in the same order. We get [type, href] per <link>.
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
    # Resolve relative URLs against the input URL.
    let parsed = $url | url parse
    let origin = $parsed.scheme + "://" + $parsed.host
    $combined | each {|f|
        if ($f | str starts-with "http") { $f } else { (
            if ($f | str starts-with "/") { $origin + $f } else { $f }
        )}
    }
}

# Process raw captured material (article, transcript, notes) into a
# structured study note with claims, quotes, open questions and keywords.
# Output is markdown ready for `iwe new "<Title>"`.
#
#   fetch <url> | distill | iwe new "Espresso essentials"
#   open --raw article.md | distill
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

# Extract verbatim quotes from a text that are about a given topic.
# Returns markdown blockquotes with brief context lines.
#
#   open minutes.md | cite "economic growth"
#   fetch <url> | cite "automation" --count 5
export def cite [
    topic: string              # the topic the quotes should be about
    --count (-n): int = 10     # max number of quotes
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

# Retrieve context from IWE for a given note key and shape it into a
# prompt-friendly background block. The bridge command between
# research/IWE and generate.
#
#   context espresso-essentials --depth 2 --shape brief
#
# Shapes:
#   background  — raw markdown from `iwe retrieve` (default)
#   brief       — runs `sum --max 10` on the output (condenses the hierarchy)
#   quotes-only — extracts only blockquotes (>) from the hierarchy
export def context [
    key: string                # IWE note key (slug)
    --depth (-d): int = 2      # inclusion-link depth (children)
    --parent-context (-c): int = 1  # levels of parent context (up)
    --max-chars: int = 16000   # hard cap (~4000 tokens) to avoid prompt overflow
    --shape: string = "background"  # background | brief | quotes-only
] {
    require iwe
    let raw = ^iwe retrieve -k $key -d $depth -c $parent_context -f markdown
    let shaped = match $shape {
        "background"  => $raw
        "brief"       => ($raw | sum --max 10)
        "quotes-only" => ($raw | lines | where ($it | str trim | str starts-with ">") | str join "\n")
        _ => (error make {msg: $"context: unknown --shape '($shape)' \(use background, brief, quotes-only\)"})
    }
    if ($shaped | str length) > $max_chars {
        ($shaped | str substring 0..$max_chars) + "\n\n[…truncated…]"
    } else {
        $shaped
    }
}

# Helper: locate an IWE note's .md file by key.
# Tries direct match in cwd first, then a recursive glob — IWE keeps notes
# as <slug>.md, optionally nested in subdirectories (e.g. daily/2026-05-14.md).
def find-note-path [key: string] {
    let direct = $"($key).md"
    if ($direct | path exists) { return $direct }
    let matches = glob $"**/($key).md"
    if ($matches | is-not-empty) { return ($matches | first) }
    null
}

# Helper: parse a YAML frontmatter block from the start of a markdown string.
# Returns an empty record if none is present.
def parse-frontmatter [content: string] {
    let trimmed = $content | str trim --left
    if not ($trimmed | str starts-with "---") { return {} }
    let body_lines = $trimmed | lines | skip 1
    let end_idx = $body_lines
        | enumerate
        | where {|r| ($r.item | str trim) == "---"}
        | first
        | get --optional index
    if $end_idx == null { return {} }
    let yaml_block = $body_lines | take $end_idx | str join "\n"
    try { $yaml_block | from yaml } catch { {} }
}

# Build a bibliography of the sources cited in (or included by) an IWE
# document hierarchy. Follows inclusion links from the given key, reads
# each note's YAML frontmatter, and emits a markdown Sources section.
#
# Works best with notes captured via `fetch --frontmatter`, which already
# writes the `source`, `captured`, `language`, `published`, `author` fields
# that bibliography reads. Notes without frontmatter are still listed by
# title; they just lack URLs and bibliographic detail.
#
#   bibliography espresso-essentials
#   bibliography espresso-essentials --depth 3 --include-self
#
# Pipe-friendly — append to a draft directly:
#
#   open --raw draft.md \
#     | append (bibliography espresso-essentials)
#     | str join "\n\n"
#     | save -f draft-with-sources.md
export def bibliography [
    key: string                # root IWE note key
    --depth (-d): int = 2      # inclusion-link depth to follow
    --include-self             # also include the root note itself
    --heading: string = "## Sources"  # heading line for the emitted block
] {
    require iwe
    let keys = ^iwe retrieve -k $key -d $depth -f keys
        | lines
        | each {|l| $l | str trim}
        | where ($it | is-not-empty)
    let candidates = if $include_self { $keys } else { $keys | where {|k| $k != $key} }
    let entries = $candidates | each {|k|
        let path = find-note-path $k
        if $path == null {
            {key: $k, title: $k, source: null, author: null, published: null, captured: null, found: false}
        } else {
            let raw = open --raw $path
            let fm = parse-frontmatter $raw
            {
                key: $k
                title: ($fm | get --optional title | default $k)
                source: ($fm | get --optional source)
                author: ($fm | get --optional author)
                published: ($fm | get --optional published)
                captured: ($fm | get --optional captured)
                found: true
            }
        }
    }
    if ($entries | is-empty) {
        return $"($heading)\n\n\(no notes found in hierarchy under `($key)`\)\n"
    }
    let lines = $entries | each {|e|
        let title_part = if $e.source != null and $e.source != "" {
            $"[($e.title)]\(($e.source)\)"
        } else {
            $e.title
        }
        let meta_bits = (
            [($e.author | default null) ($e.published | default null) ($e.captured | default null)]
                | where {|x| $x != null and $x != ""}
                | each {|x| $x | into string}
        )
        let meta = if ($meta_bits | is-empty) { "" } else { $" — ($meta_bits | str join ', ')" }
        $"- ($title_part)($meta)"
    }
    $"($heading)\n\n($lines | str join "\n")\n"
}
