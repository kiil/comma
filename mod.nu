# comma - opinionated sprog-overlay til yoke
#
# yolay.nu er en generel agent-REPL. comma er det modsatte: et stramt
# sæt sprog-kommandoer der hver returnerer KUN den bearbejdede tekst.
# Ingen samtale-ctx, ingen værktøjer, ingen markdown-pynt — bare tekst
# ind, tekst ud, klar til pipe.
#
# Quick start:
#   overlay use comma
#   "Hello, world" | tr da
#   "denne tekst er for lang og snørklet" | rw "kortere og klarere"
#   open notat.md | sum
#   "blogpost om kaffe-extraction" | draft --words 200
#   "elsker det her produkt" | sentiment
#
# Filer:
#   transform.nu — tr, rw, sum, proof, tone     (tekst ind → omformet tekst ud)
#   generate.nu  — draft, expand, title, ideas, ask  (brief/emne → ny tekst)
#   analyze.nu   — detect, sentiment, keywords, entities, readability, classify
#
# Designprincipper:
# - Hver kommando er stateless. Ingen $env.YO_CTX. Hver invokation er én tur.
# - Default tools=none. Sprogopgaver må ikke kalde shell/web/kode.
# - Output er ren tekst uden citationstegn, indledninger eller forklaringer.
# - Pipeline er førsteklasses input. Positionsargumenter er kun til korte
#   inline-strenge.

export use transform.nu *
export use generate.nu *
export use analyze.nu *
export use pipeline.nu *
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

# Vis nuværende config og en kort liste over kommandoer.
export def status [] {
    let c = comma-cfg
    print $"(ansi cyan_bold)comma(ansi reset) · ($c.provider)/($c.model) · tools: ($c.tools)"
    print $"(ansi attr_dimmed)transform: tr · rw · sum · proof · tone(ansi reset)"
    print $"(ansi attr_dimmed)generate:  draft · expand · title · ideas · ask(ansi reset)"
    print $"(ansi attr_dimmed)analyze:   stats · freq · ngrams · kwic · lix · repeats · compare · hapax · ttr · similar · report(ansi reset)"
    print $"(ansi attr_dimmed)           sentences · paragraphs · extract(ansi reset)"
    print $"(ansi attr_dimmed)analyze\(LLM\): detect · sentiment · keywords · entities · readability · classify · factcheck · quotes · claims(ansi reset)"
    print $"(ansi attr_dimmed)pipeline:  polish(ansi reset)"
    print $"(ansi attr_dimmed)publish:   to-pdf · to-html · to-docx · to-epub · to-typst · typst-compile · preview · pub(ansi reset)"
    print $"(ansi attr_dimmed)research:  fetch · distill · cite · context(ansi reset)"
    print $"(ansi attr_dimmed)           \(analyze: gemini-3-pro-preview + web_search,nu — overstyr via COMMA_ANALYZE_CFG\)(ansi reset)"
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

# publish
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

# meta
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
    print $"(ansi attr_dimmed)transform · generate · analyze — ,? for liste(ansi reset)"
}
