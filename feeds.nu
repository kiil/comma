# comma · feeds — manage RSS/Atom feed subscriptions via a feed-reader
# provider. The current default (and only) provider is blogtato; the
# module is structured so additional providers (newsboat, miniflux,
# tt-rss, …) can be added later without changing the command surface.
#
# Provider is chosen via $env.COMMA_FEEDS_PROVIDER (default: "blogtato").
#
# Note: there is also a `feeds <url>` command in research.nu that
# discovers feed URLs on a webpage. That is a different (one-shot,
# stateless) operation. The two compose naturally:
#
#     research.feeds "https://example.com" | each {|u| subscribe $u}
#
# Dependencies (one of):
#   blogtato — `cargo install blogtato`. CLI binary is `blog`.
#              https://github.com/kantord/blogtato

def require [cmd: string] {
    if (which $cmd | is-empty) {
        error make {msg: $"feeds: '($cmd)' not found in PATH. Install the corresponding provider."}
    }
}

def active-provider [] {
    $env | get COMMA_FEEDS_PROVIDER? | default "blogtato"
}

def unknown-provider [p: string] {
    error make {msg: $"feeds: unknown provider '($p)'. Supported: blogtato. Set $env.COMMA_FEEDS_PROVIDER."}
}

# --- Subscriptions ---

# Subscribe to a new RSS/Atom feed.
#
#   subscribe "https://blog.example.com/feed.xml"
export def subscribe [
    url: string                # feed URL (RSS or Atom)
] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog feed add $url
        }
        _ => (unknown-provider $p)
    }
}

# Unsubscribe from a feed. Accepts the feed URL or a provider-specific
# shorthand (blogtato uses `@xxxx` shorthands listed by `subs`).
#
#   unsubscribe "@shds"
#   unsubscribe "https://blog.example.com/feed.xml"
export def unsubscribe [
    key: string                # feed URL or shorthand
] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog feed rm $key
        }
        _ => (unknown-provider $p)
    }
}

# List subscribed feeds as a structured table. Each row has shorthand,
# url, and (where available) title.
#
#   subs
#   subs | where ($it.title? | default "" | str contains "AI")
export def subs [] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            # blogtato prints lines like: `@<shorthand> <url> (<title>)`
            # Title is optional — older subscriptions may not have one.
            ^blog feed ls
                | lines
                | where ($it | str trim | is-not-empty)
                | each {|line|
                    let trimmed = $line | str trim
                    let parsed = $trimmed | parse --regex '^@(?P<shorthand>\S+)\s+(?P<url>\S+)(?:\s+\((?P<title>.+)\))?$'
                    if ($parsed | is-empty) {
                        {shorthand: null, url: $trimmed, title: null}
                    } else {
                        $parsed | first
                    }
                }
        }
        _ => (unknown-provider $p)
    }
}

# Fetch updates from every subscribed feed.
#
#   sync
export def sync [] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog sync
        }
        _ => (unknown-provider $p)
    }
}

# --- Posts ---

# Query posts as a structured table. Optional query arguments are passed
# verbatim to the provider's query language (blogtato: filters like
# `.unread`, `@shorthand`, date ranges like `1w..`, groupings like `/d`).
#
# Each row carries both `id` (stable 16-hex internal id, useful for
# deduplication) and `shorthand` (blogtato's single-letter session
# shorthand — what `blog <letter> <action>` actually accepts). The
# shorthand is position-based and re-assigned after each `sync`; treat
# it as session-scoped.
#
#   posts                       # default query
#   posts .unread 1w..          # unread in last week
#   posts @shds                 # only from feed @shds
#   posts .all 3m..1m           # all posts between 3 and 1 month ago
export def posts [
    ...query: string           # provider-specific query terms
] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            let records = ^blog export ...$query
                | lines
                | where ($it | str trim | is-not-empty)
                | each {|l| try { $l | from json } catch { null } }
                | compact
            # Parse the parallel show output to recover the per-row
            # single-letter shorthand (blogtato emits e.g.
            # `* 2026-05-15  a <title> (@feed Title)`). show and export
            # use the same query and are in identical row order.
            let shorthands = ^blog ...$query
                | lines
                | each {|l|
                    let m = $l | parse --regex '^\* \S+\s+(?P<sh>\S)\s'
                    if ($m | is-empty) { null } else { ($m | first).sh }
                }
                | compact
            $records | enumerate | each {|r|
                let sh = $shorthands | get --optional $r.index
                $r.item | upsert shorthand $sh
            }
        }
        _ => (unknown-provider $p)
    }
}

# Convenience: list unread posts as a table.
#
#   unread
#   unread 1w..             # extra query terms passed through
export def unread [
    ...query: string
] {
    posts ".unread" ...$query
}

# Helper: resolve a post shorthand from either pipe input or a positional
# argument, so action commands can be called both ways:
#
#   open-post a                    # positional, single-letter shorthand
#   unread | first | open-post     # pipe a record (uses its `.shorthand`)
#   "a" | open-post                # pipe a string
#
# The shorthand for blogtato is a single letter (a-l, A-L) assigned by
# the current `blog` show output — not the 16-hex internal id. The id
# field is preserved on records for deduplication but cannot be used
# with `blog <action>`.
#
# Errors when neither input is present, or when the piped value cannot
# be interpreted as a shorthand.
def resolve-shorthand [piped: any, positional: any] {
    if $positional != null and $positional != "" { return $positional }
    if $piped == null {
        error make {msg: "feeds: pass a post shorthand as an argument or pipe a post record/string in"}
    }
    let d = $piped | describe
    if ($d | str starts-with "string") { return $piped }
    if ($d | str starts-with "record") {
        let sh = $piped | get --optional shorthand
        if $sh == null {
            error make {msg: "feeds: piped record has no `shorthand` field — was it produced by this module's `posts`/`unread`/`latest`/`pick`?"}
        }
        return $sh
    }
    error make {msg: $"feeds: cannot resolve shorthand from piped value of type ($d) — pipe a string or a record with a `shorthand` field"}
}

# Open a post in the default browser (does not mark read).
#
#   open-post "6dfcc1fdbc4818f6"
#   unread | first | open-post
export def open-post [
    shorthand?: string         # post id (or pipe a record/string)
] {
    let id = resolve-shorthand $in $shorthand
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog open $id
        }
        _ => (unknown-provider $p)
    }
}

# Mark a post as read and return its URL on stdout.
#
#   mark-read "6dfcc1fdbc4818f6"
#   unread | first | mark-read | fetch $in | distill | iwe new "Captured post"
export def mark-read [
    shorthand?: string         # post id (or pipe a record/string)
] {
    let id = resolve-shorthand $in $shorthand
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog read $id
        }
        _ => (unknown-provider $p)
    }
}

# Mark a post as unread.
#
#   mark-unread "6dfcc1fdbc4818f6"
#   posts @spam-feed | each {|p| $p | mark-unread}
export def mark-unread [
    shorthand?: string         # post id (or pipe a record/string)
] {
    let id = resolve-shorthand $in $shorthand
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog unread $id
        }
        _ => (unknown-provider $p)
    }
}

# --- Lookup helpers ---

# Return the most recent post as a record, optionally filtered.
#
#   latest                       # most recent post overall
#   latest .unread               # most recent unread post
#   latest @shds                 # most recent from feed @shds
#   latest | open-post           # open whatever was newest
export def latest [
    ...query: string           # extra query terms passed to posts
] {
    let candidates = posts ...$query
    if ($candidates | is-empty) {
        error make {msg: "latest: no posts match the query"}
    }
    $candidates | sort-by date --reverse | first
}

# Search posts by title (case-insensitive substring match). Extra query
# terms are passed through to `posts` first to narrow the search space.
#
#   find-post espresso
#   find-post "AI safety" .unread
#   find-post coffee | first | mark-read
export def find-post [
    needle: string             # substring to match against the post title
    ...filter: string          # extra query terms passed to posts
] {
    let target = $needle | str downcase
    posts ...$filter | where {|p| ($p.title | str downcase | str contains $target)}
}

# Interactive fzf picker over a posts result. Returns the selected post
# as a record — pipe straight into an action command.
#
#   pick                            # pick from all posts (default query)
#   pick .unread                    # pick from unread
#   pick @shds 1w.. | open-post     # pick from feed @shds in last week, open it
#   pick | mark-read | fetch $in | distill | iwe new "Captured"
#
# Dependency: `fzf` on PATH.
export def pick [
    ...query: string           # query terms passed to posts
] {
    require fzf
    let candidates = posts ...$query
    if ($candidates | is-empty) {
        error make {msg: "pick: no posts match the query"}
    }
    let lines = $candidates | each {|p|
        let feed_title = $p.feed?.title? | default "?"
        $"($p.id)\t($p.title)\t— ($feed_title)"
    }
    let selected = $lines
        | str join "\n"
        | ^fzf --delimiter "\t" --with-nth "2.." --prompt "post> " --ansi
        | str trim
    if ($selected | is-empty) {
        error make {msg: "pick: nothing selected"}
    }
    let id = $selected | split row "\t" | first
    $candidates | where id == $id | first
}

# --- Import / export ---

# Import subscriptions from an OPML file.
#
#   import-opml subscriptions.opml
export def import-opml [
    file: path                 # OPML file
] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog feed import $file
        }
        _ => (unknown-provider $p)
    }
}

# Export subscriptions as OPML on stdout.
#
#   export-opml | save -f my-feeds.opml
export def export-opml [] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog feed export
        }
        _ => (unknown-provider $p)
    }
}
