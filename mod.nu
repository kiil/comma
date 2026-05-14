# comma — opinionated language overlay for yoke
#
# yolay.nu is a general agent REPL. comma is its opposite: a tight set of
# language commands that each return ONLY the processed text. No conversation
# context, no tools, no markdown decoration — just text in, text out, ready
# to pipe.
#
# Quick start:
#   overlay use comma
#   "Hello, world" | tr da
#   "this text is too long and convoluted" | rw "shorter and clearer"
#   open notat.md | sum
#   "blog post about coffee extraction" | draft --words 200
#   "love this product" | sentiment
#
# Files:
#   transform.nu — tr, rw, sum, proof, tone       (text in → rewritten text out)
#   generate.nu  — draft, expand, title, ideas, ask  (brief/topic → new text)
#   analyze.nu   — stats, freq, lix, … + detect, sentiment, keywords, entities,
#                  readability, classify
#   validate.nu  — factcheck, quotes, claims (verification with web_search)
#   research.nu  — fetch, meta, links, feeds, distill, cite, context
#   pipeline.nu  — polish (the critic loop)
#   publish.nu   — to-pdf, to-html, to-docx, to-epub, to-typst, preview, pub
#
# Design principles:
# - Every command is stateless. No $env.YO_CTX. Each invocation is one turn.
# - Default tools=none. Language tasks may not call shell/web/code.
# - Output is plain text — no quotation marks, preambles or explanations.
# - Pipeline input is first-class. Positional arguments are for short inline
#   strings only.

export use transform.nu *
export use generate.nu *
export use analyze.nu *
export use validate.nu *
export use pipeline.nu *
export use convert.nu *
export use publish.nu *
export use research.nu *

# --- Defaults ---

const PROVIDER = "gemini"
const MODEL    = "gemini-3.1-flash-lite-preview"
const TOOLS    = "none"

def comma-cfg [] {
    $env | get COMMA_CFG? | default {
        provider: $PROVIDER
        model: $MODEL
        tools: $TOOLS
    }
}

# Print the current config and a short list of commands.
export def status [] {
    let c = comma-cfg
    print $"(ansi cyan_bold)comma(ansi reset) · ($c.provider)/($c.model) · tools: ($c.tools)"
    print $"(ansi attr_dimmed)transform: tr · rw · sum · proof · tone(ansi reset)"
    print $"(ansi attr_dimmed)generate:  draft · expand · title · ideas · ask(ansi reset)"
    print $"(ansi attr_dimmed)analyze:   stats · freq · ngrams · kwic · lix · repeats · compare · hapax · ttr · similar · report(ansi reset)"
    print $"(ansi attr_dimmed)           sentences · paragraphs · extract(ansi reset)"
    print $"(ansi attr_dimmed)analyze\(LLM\): detect · sentiment · keywords · entities · readability · classify(ansi reset)"
    print $"(ansi attr_dimmed)validate:  factcheck · quotes · claims(ansi reset)"
    print $"(ansi attr_dimmed)pipeline:  polish(ansi reset)"
    print $"(ansi attr_dimmed)convert:   to-pdf · to-html · to-docx · to-epub · to-typst · typst-compile · preview · pub(ansi reset)"
    print $"(ansi attr_dimmed)publish:   \(reserved — platform-publishing APIs\)(ansi reset)"
    print $"(ansi attr_dimmed)research:  fetch · meta · links · feeds · distill · cite · context(ansi reset)"
    print $"(ansi attr_dimmed)           \(validate: gemini-3-pro-preview + web_search,nu — override via COMMA_VALIDATE_CFG\)(ansi reset)"
}

# Change model/provider for the rest of the session.
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

# --- Aliases (comma-prefix, like yolay) ---

# transform
export alias ,t  = tr
export alias ,r  = rw
export alias ,s  = sum
export alias ,p  = proof
export alias ,o  = tone

# generate
export alias ,dr = draft
export alias ,ex = expand
export alias ,ti = title
export alias ,id = ideas
export alias ,as = ask

# analyze
export alias ,de = detect
export alias ,se = sentiment
export alias ,kw = keywords
export alias ,en = entities
export alias ,rd = readability
export alias ,cl = classify
export alias ,fc = factcheck
export alias ,qu = quotes
export alias ,cm = claims
export alias ,st = stats
export alias ,fq = freq
export alias ,ng = ngrams
export alias ,kc = kwic
export alias ,lx = lix
export alias ,rp = repeats
export alias ,cp = compare
export alias ,hp = hapax
export alias ,tt = ttr
export alias ,sl = similar
export alias ,sn = sentences
export alias ,pa = paragraphs
export alias ,xt = extract
export alias ,rt = report

# pipeline
export alias ,po = polish

# convert
export alias ,pd = to-pdf
export alias ,hl = to-html
export alias ,dx = to-docx
export alias ,ep = to-epub
export alias ,tp = to-typst
export alias ,pv = preview
export alias ,pb = pub

# research
export alias ,fe = fetch
export alias ,di = distill
export alias ,ci = cite
export alias ,cx = context
export alias ,mt = meta
export alias ,lk = links
export alias ,fd = feeds

# session
export alias ,?  = status
export alias ,m  = model

# --- Overlay init ---

export-env {
    $env.COMMA_CFG = $env | get COMMA_CFG? | default {
        provider: $PROVIDER
        model: $MODEL
        tools: $TOOLS
    }
    print $"(ansi cyan_bold)comma overlay(ansi reset) loaded · ($env.COMMA_CFG.provider)/($env.COMMA_CFG.model)"
    print $"(ansi attr_dimmed)transform · generate · analyze — ,? for list(ansi reset)"
}
