# comma · iwe — wrappers around the IWE (https://iwe.md) CLI that
# reshape its output into nu records/tables and accept piped input where
# it makes sense.
#
# Naming: every command in this module is prefixed `iwe-`. The bare
# names `stats`, `extract`, `tree`, etc. would collide with existing
# comma commands (and with nu's built-ins in some cases). The prefix
# also makes it obvious which operations talk to the iwe binary.
#
# Where comma's research.nu already wraps an iwe operation with a
# specific intent (`context` over `iwe retrieve`, `bibliography` over
# the inclusion-link hierarchy), those stay there. iwe.nu is the
# generic-wrapper layer; research.nu is the comma-flavoured one.
#
# Dependency: iwe on PATH (https://iwe.md). All commands must be run
# from inside an IWE workspace (a directory with a `.iwe/` folder).

def require [cmd: string] {
    if (which $cmd | is-empty) {
        error make {msg: $"iwe: '($cmd)' not found in PATH. See https://iwe.md for installation."}
    }
}

# Initialize the current directory as an IWE workspace.
#
#   cd ~/my-notes
#   iwe-init
export def iwe-init [] {
    require iwe
    ^iwe init
}

# Create a new document. Content can come from the pipe, the --content
# flag, or stdin redirection. Returns the path of the created file as
# emitted by iwe.
#
#   "Body of the note" | iwe-new "My note title"
#   iwe-new "My note title" --content "..."
#   open --raw draft.md | iwe-new "Imported draft"
export def iwe-new [
    title: string              # title — IWE slugifies this for the filename
    --content (-c): string     # inline content (alternative to piping)
    --template (-t): string    # template name from .iwe/config.toml
] {
    require iwe
    let piped = $in
    mut args = [new $title]
    if $template != null { $args = ($args | append ["--template" $template]) }
    if $content != null {
        $args = ($args | append ["--content" $content])
        ^iwe ...$args
    } else if $piped != null {
        let src = if ($piped | describe) == "string" { $piped } else { $piped | to text }
        $src | ^iwe ...$args
    } else {
        ^iwe ...$args
    }
}

# Search documents — fuzzy match on title and key, optionally narrowed
# by filter flags. Returns a table of records with `key`, `title`,
# `references`, plus whatever frontmatter projection iwe surfaces.
#
#   iwe-find espresso
#   iwe-find --limit 5
#   iwe-find --filter "status: draft"
#   iwe-find --included-by espresso-essentials
export def iwe-find [
    query?: string             # fuzzy match on title/key
    --limit (-l): int          # max results (0 = unlimited)
    --filter: string           # inline YAML filter expression
    --key (-k): string         # match by exact key
    --includes: string         # filter: this document includes <key>
    --included-by: string      # filter: this document is included by <key>
    --references: string       # filter: this document references <key>
    --referenced-by: string    # filter: this document is referenced by <key>
] {
    require iwe
    mut args = [find --format json]
    if $query != null { $args = ($args | append $query) }
    if $limit != null { $args = ($args | append ["--limit" ($limit | into string)]) }
    if $filter != null { $args = ($args | append ["--filter" $filter]) }
    if $key != null { $args = ($args | append ["--key" $key]) }
    if $includes != null { $args = ($args | append ["--includes" $includes]) }
    if $included_by != null { $args = ($args | append ["--included-by" $included_by]) }
    if $references != null { $args = ($args | append ["--references" $references]) }
    if $referenced_by != null { $args = ($args | append ["--referenced-by" $referenced_by]) }
    ^iwe ...$args | from json
}

# Count documents matching a filter — convenience over `iwe-find | length`
# that lets iwe do the counting (much faster on large graphs).
#
#   iwe-count
#   iwe-count --filter "status: draft"
export def iwe-count [
    --filter: string
    --key (-k): string
    --included-by: string
    --references: string
] {
    require iwe
    mut args = [count]
    if $filter != null { $args = ($args | append ["--filter" $filter]) }
    if $key != null { $args = ($args | append ["--key" $key]) }
    if $included_by != null { $args = ($args | append ["--included-by" $included_by]) }
    if $references != null { $args = ($args | append ["--references" $references]) }
    ^iwe ...$args | str trim | into int
}

# Display the document hierarchy as a structured tree. Default format
# returns nested records; pass --format markdown for the human view.
#
#   iwe-tree
#   iwe-tree --depth 3
#   iwe-tree --key espresso-essentials
#   iwe-tree --format markdown      # human-readable nested list
export def iwe-tree [
    --depth (-d): int = 4      # maximum nesting depth
    --key (-k): string         # start tree from this document
    --filter: string
    --format: string = "json"  # json | yaml | markdown | keys
] {
    require iwe
    mut args = [tree --format $format --depth ($depth | into string)]
    if $key != null { $args = ($args | append ["--key" $key]) }
    if $filter != null { $args = ($args | append ["--filter" $filter]) }
    let raw = ^iwe ...$args
    match $format {
        "json" => ($raw | from json)
        "yaml" => ($raw | from yaml)
        _ => $raw
    }
}

# Workspace statistics — document count, references, top documents by
# sections, network analytics. Returns a record.
#
#   iwe-stats
#   iwe-stats | get totalDocuments
#   iwe-stats | get topDocsBySections | first 5
export def iwe-stats [
    --key (-k): string         # restrict to a single document (always JSON)
] {
    require iwe
    mut args = [stats -f json]
    if $key != null { $args = ($args | append ["--key" $key]) }
    ^iwe ...$args | from json
}

# Retrieve a document with its children/parents. Thin wrapper — for
# the prompt-shaped variant used by --notes flags, see research.context.
#
#   iwe-retrieve espresso-essentials                       # default markdown
#   iwe-retrieve espresso-essentials --depth 3 --format yaml
#   iwe-retrieve espresso-essentials --format json | get content
export def iwe-retrieve [
    key: string                # document key
    --depth (-d): int = 1      # how many levels of children to follow
    --context (-c): int = 1    # how many levels of parent context to include
    --format (-f): string = "markdown"  # markdown | keys | json | yaml
    --links (-l)               # also include inline-referenced documents
    --backlinks (-b)           # also include incoming references
] {
    require iwe
    mut args = [
        retrieve -k $key
        -d ($depth | into string)
        -c ($context | into string)
        -f $format
    ]
    if $links { $args = ($args | append "--links") }
    if $backlinks { $args = ($args | append "--backlinks") }
    let raw = ^iwe ...$args
    match $format {
        "json" => ($raw | from json)
        "yaml" => ($raw | from yaml)
        _ => $raw
    }
}

# Squash a document tree into one consolidated markdown document.
# Non-destructive — source files are not modified. The right tool when
# you have written a skeleton with inclusion links and want to render
# the assembled draft.
#
#   iwe-squash espresso-article | save -f draft.md
#   iwe-squash espresso-article | polish --brief "espresso article"
export def iwe-squash [
    key: string                # starting document key
    --depth (-d): int = 2      # how many levels of inclusion links to follow
] {
    require iwe
    ^iwe squash $key -d ($depth | into string)
}

# Attach a source document as a block reference under one or more
# configured attach actions (see .iwe/config.toml). Without `--to`,
# lists the configured attach actions.
#
#   iwe-attach --list                             # show configured actions
#   iwe-attach -k coffee-deep-dive --to daily
#   iwe-attach -k coffee-deep-dive --to daily --dry-run
export def iwe-attach [
    --key (-k): string         # source document key (must exist)
    --to: string               # target attach-action name from .iwe/config.toml
    --list                     # list configured attach actions instead
    --dry-run                  # preview without writing
] {
    require iwe
    if $list {
        ^iwe attach --list
        return
    }
    if $key == null or $to == null {
        error make {msg: "iwe-attach: provide both -k <source-key> and --to <action> (or use --list)"}
    }
    mut args = [attach -k $key --to $to]
    if $dry_run { $args = ($args | append "--dry-run") }
    ^iwe ...$args
}

# Rename a document. All inclusion links and references across the
# workspace are updated automatically.
#
#   iwe-rename old-name new-name
export def iwe-rename [
    old: string                # current key
    new: string                # new key
] {
    require iwe
    ^iwe rename $old $new
}

# Delete a document and clean up references to it across the workspace.
#
#   iwe-delete obsolete-note
export def iwe-delete [
    key: string                # document key
    --dry-run                  # preview the changes
] {
    require iwe
    mut args = [delete $key]
    if $dry_run { $args = ($args | append "--dry-run") }
    ^iwe ...$args
}

# Normalize all markdown files in the workspace — consistent header
# levels, link formats, frontmatter formatting. Useful as a periodic
# cleanup or before committing to git.
#
#   iwe-normalize
#   iwe-normalize --dry-run
export def iwe-normalize [
    --dry-run
] {
    require iwe
    mut args = [normalize]
    if $dry_run { $args = ($args | append "--dry-run") }
    ^iwe ...$args
}
