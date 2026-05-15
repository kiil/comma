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
            ^blog export ...$query
                | lines
                | where ($it | str trim | is-not-empty)
                | each {|l| try { $l | from json } catch { null } }
                | compact
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

# Open a post in the default browser (does not mark read).
#
#   open-post "6dfcc1fdbc4818f6"
export def open-post [
    shorthand: string          # post id from posts/unread output
] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog open $shorthand
        }
        _ => (unknown-provider $p)
    }
}

# Mark a post as read and return its URL on stdout.
#
#   mark-read "6dfcc1fdbc4818f6"
#   mark-read "6dfcc1fdbc4818f6" | fetch $in | distill | iwe new "Captured post"
export def mark-read [
    shorthand: string
] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog read $shorthand
        }
        _ => (unknown-provider $p)
    }
}

# Mark a post as unread.
#
#   mark-unread "6dfcc1fdbc4818f6"
export def mark-unread [
    shorthand: string
] {
    let p = active-provider
    match $p {
        "blogtato" => {
            require blog
            ^blog unread $shorthand
        }
        _ => (unknown-provider $p)
    }
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
