---
title: "feeds"
parent: "Reference"
nav_order: 7
---

# Reference: feeds

Manage RSS/Atom feed subscriptions via a feed-reader provider. Thin wrapper that makes a chosen provider (default: blogtato) feel like the rest of comma — pipe-friendly, structured output, deterministic where the underlying tool allows.

> **Naming note:** `feeds.nu` is the subscription-and-reading module here. There is also a `feeds <url>` command in [research](research.md#feeds) that *discovers* feed URLs on a webpage. They compose naturally:
>
> ```nu
> research.feeds "https://example.com" | each {|u| subscribe $u}
> ```

## Provider

Selected via `$env.COMMA_FEEDS_PROVIDER` (default: `"blogtato"`).

**Currently supported:** `blogtato` only. The module is structured so additional providers (newsboat, miniflux CLI, tt-rss-cli, …) can be added without changing the command surface.

**Dependencies (provider-specific):**
- blogtato: `cargo install blogtato` — CLI binary is `blog`.

Each command calls `require <binary>` at start; missing dependencies fail with a clear error.

## Subscriptions

### `subscribe`

Subscribe to a new feed.

```
subscribe <url>
```

### `unsubscribe`

Remove a feed. Accepts either the URL or a provider-specific shorthand (blogtato uses `@xxxx` shorthands).

```
unsubscribe <key>
```

### `subs`

List subscribed feeds as a structured table with `shorthand`, `url`, `title` columns.

```
subs
```

**Example:**

```nu
subs | where ($it.title? | default "" | str contains "AI")
subs | get url | save -f feeds.txt
```

## Sync

### `sync`

Fetch updates from every subscribed feed.

```
sync
```

## Posts

### `posts`

Query posts as a structured table. Extra arguments are passed verbatim to the provider's query language.

For blogtato:

| Term | Effect |
|---|---|
| `.unread` | only unread posts |
| `.read` | only read posts |
| `.all` | all posts |
| `@shorthand` | only posts from a specific feed |
| `1w..` | from one week ago onward |
| `3m..1m` | between three and one months ago |
| `/d` | group by date |
| `/f` | group by feed |

```
posts [...query]
```

**Example:**

```nu
posts                                 # default query
posts .unread 1w..
posts @shds                           # only from feed @shds
posts .read 1y.. | length             # how many posts have I read this year
```

Returns a table of records with `shorthand`, `id`, `title`, `date`, `feed.{url,title,site_url,description}`, `link`.

| Field | What | Stability |
|---|---|---|
| `shorthand` | Single letter (a–l, A–L) — what `blog <letter> <action>` accepts | **Session-scoped** — re-assigned after each `sync` |
| `id` | 16-hex internal id from blogtato's posts.jsonl | Stable |
| `title` | Post title from the feed | Stable |
| `link` | Canonical URL of the post | Stable |

The `shorthand` is the field you want for downstream action commands (`open-post`, `mark-read`, `mark-unread`). The `id` is useful for deduplication across runs but **cannot** be used with `blog <action>` — blogtato only accepts the single-letter form.

Composes well with `fetch`, `distill`, `iwe new`:

```nu
unread | each {|p| fetch $p.link | distill | iwe new $p.title }
```

### `unread`

Convenience shortcut for `posts .unread`. Extra arguments are appended to the query.

```
unread [...query]
```

**Example:**

```nu
unread                                # unread posts (default range)
unread 1w..                           # unread in last week
```

## Lookup helpers

These return post records (or pick interactively) so you do not have to read shorthand IDs off a table and paste them. All three compose with the action commands below — the result of any of them can be piped directly into `open-post`, `mark-read` or `mark-unread`.

### `latest`

Return the most recent matching post as a record.

```
latest [...query]
```

**Example:**

```nu
latest                          # most recent post overall
latest .unread                  # most recent unread
latest @shds                    # most recent from feed @shds
latest .unread | open-post      # open the newest unread
```

### `find-post`

Filter posts by case-insensitive substring match against the title. Extra query terms narrow the search space first.

```
find-post <needle> [...filter]
```

**Example:**

```nu
find-post espresso
find-post "AI safety" .unread
find-post coffee | first | mark-read
```

### `pick`

Interactive [fzf](https://github.com/junegunn/fzf) picker over a posts query. Returns the selected post as a record. The shorthand IDs are hidden from the fzf prompt — you choose by title and feed name.

```
pick [...query]
```

**Dependency:** `fzf` on PATH.

**Example:**

```nu
pick                                # pick from all posts
pick .unread                        # pick from unread
pick @shds 1w.. | open-post         # browse a feed's recent posts
pick | mark-read | fetch $in | distill | iwe new "Captured"
```

## Action commands

These three accept the post shorthand either as a positional argument *or* via pipe (a post record or a bare id string). The pipe form is the recommended pattern — you rarely need to see or type the shorthand at all.

### `open-post`

Open a post in the system default browser. Does *not* mark the post as read.

```
open-post [<shorthand>]
```

**Example:**

```nu
open-post 6dfcc1fdbc4818f6
latest .unread | open-post
pick .unread | open-post
```

### `mark-read`

Mark a post as read. Returns the post's URL on stdout so the command composes with downstream consumers.

```
mark-read [<shorthand>]
```

**Example:**

```nu
mark-read 6dfcc1fdbc4818f6
latest .unread | mark-read | fetch $in | distill | iwe new "Captured post"
find-post boring | each {|p| $p | mark-read}      # bulk-dismiss
```

### `mark-unread`

Mark a post as unread.

```
mark-unread [<shorthand>]
```

**Example:**

```nu
mark-unread 6dfcc1fdbc4818f6
posts .read @misclicked-feed | each {|p| $p | mark-unread}
```

### Resolving the shorthand from pipe input

When called without a positional argument, the action commands look at `$in`:

| Piped type | Behaviour |
|---|---|
| string | used as the shorthand directly (expect single letter for blogtato) |
| record with `.shorthand` field | `shorthand` is extracted |
| record without `.shorthand` | error — was the record produced by this module's `posts`/`unread`/`latest`/`pick`? |
| anything else | error with a clear message |

Lists are not handled implicitly — use `each {|p| $p | mark-read}` for bulk operations. That keeps the action commands' contract simple and lets you compose them with any nu iteration construct.

### Caveat: shorthand stability

blogtato's single-letter shorthand is assigned by **position in the current query result**. That means:

- `latest .unread | get shorthand` today and tomorrow refer to *different* posts (the top of the unread list will have shifted as you mark things read or as new posts arrive).
- After `sync`, all shorthand letters are re-assigned.
- Across different queries, the same letter (`a`) can refer to different posts.

Use shorthands **within a session** — same query, no sync in between. If you need to store a reference to a specific post over time, save its `id` or `link` instead and look it up again later.

## Import / export

### `import-opml`

Import subscriptions from an OPML file.

```
import-opml <file>
```

### `export-opml`

Export current subscriptions as OPML to stdout.

```
export-opml
```

**Example:**

```nu
export-opml | save -f my-feeds.opml
```

## Adding a new provider

The pattern is a `match` on `active-provider` inside each exported command. Each provider's branch shells out to its own CLI and reshapes the output to the same comma-side schema (table of records for `posts`/`subs`, plain text for command-style operations). Add a new provider by:

1. Adding a new arm to each `match` in `feeds.nu` (e.g. `"newsboat" => { ... }`).
2. Documenting the binary it requires (the existing `require <cmd>` helper handles missing-PATH errors cleanly).
3. Mapping the provider's data shape to the same column names: `shorthand`, `url`, `title` for `subs`; `id`, `title`, `date`, `feed.*`, `link` for `posts`.

Where a provider doesn't support an operation (e.g., no shorthand concept, no `mark-unread`), that arm should `error make` with a clear message rather than silently no-op.
