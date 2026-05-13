# comma · pipeline — the critic loop. Orchestrates transform, generate
# and analyze into an iterative refine flow.
#
# Principle:
#   1. If no draft is piped in but --brief is given, generate a draft.
#   2. Each pass runs deterministic critics (lix, repeats) plus optional
#      LLM critics (proof, readability) depending on --level.
#   3. Each finding maps to a targeted fix — we PATCH, we don't redraft.
#   4. The brief is appended as an anti-drift anchor.
#   5. Stop on: no findings · hash convergence · max-passes reached.
#
# Design choices:
# - Deterministic critics are the stop condition. LLM critics can find
#   "issues" forever — we only trust them while the hard thresholds are
#   not yet met.
# - factcheck/quotes at the publication level are REPORTED, not auto-fixed
#   — they require human judgment.
# - Verbose log goes to stderr so stdout stays pipe-clean.

use transform.nu *
use analyze.nu *
use validate.nu *
use generate.nu *

# Iterative critic loop: optionally generate a draft, analyze it, patch,
# repeat until convergence. Returns plain text on stdout.
#
#   open draft.md | polish
#   polish --brief "blog post about espresso extraction" --verbose
#   open speech.md | polish --level publication --max-passes 3
export def polish [
    --level (-L): string = "editorial"  # light | editorial | publication
    --max-passes: int = 4               # hard cap on iterations
    --lix-min: int = 30                 # lower Lix bound (below = "too monotone")
    --lix-max: int = 50                 # upper Lix bound (above = "too heavy")
    --repeat-min-length: int = 4        # flag n-grams of this length that repeat
    --brief: string                     # original brief — anti-drift anchor
    --verbose (-v)                      # log each pass to stderr
    ...text: string
] {
    let piped = $in
    let initial = resolve-initial $piped $text $brief $verbose

    mut draft = $initial
    mut log = []
    mut warnings = []

    if $max_passes < 1 { return $draft }
    for pass in 1..$max_passes {
        let result = critique $draft $level $lix_min $lix_max $repeat_min_length
        let findings = $result.findings
        let warns = $result.warnings

        if ($warns | is-not-empty) {
            $warnings = ($warnings | append $warns)
        }

        if ($findings | is-empty) {
            if $verbose { print --stderr $"(ansi green)pass ($pass): clean, stopping(ansi reset)" }
            $log = ($log | append {pass: $pass, findings: 0, action: "clean"})
            break
        }

        if $verbose {
            print --stderr $"(ansi cyan)pass ($pass)(ansi reset): ($findings | length) finding\(s\)"
            for f in $findings {
                print --stderr $"  · ($f.kind) [sev ($f.severity)]: ($f.description)"
            }
        }

        let prev_hash = $draft | hash sha256
        for f in $findings {
            $draft = (apply-fix $draft $f $brief)
        }
        let new_hash = $draft | hash sha256

        $log = ($log | append {
            pass: $pass
            findings: ($findings | length)
            changed: ($prev_hash != $new_hash)
        })

        if $prev_hash == $new_hash {
            if $verbose { print --stderr $"(ansi yellow)pass ($pass): converged \(hash unchanged\), stopping(ansi reset)" }
            break
        }
    }

    if $verbose {
        print --stderr ""
        print --stderr "=== revision log ==="
        print --stderr ($log | table)
        if ($warnings | is-not-empty) {
            print --stderr ""
            print --stderr $"(ansi red_bold)=== warnings \(require manual review\) ===(ansi reset)"
            for w in $warnings {
                print --stderr $"(ansi red)[($w.kind)](ansi reset) ($w.description)"
                print --stderr $w.body
                print --stderr ""
            }
        }
    }

    $draft
}

# Determine the initial text: pipe > argument > brief generation.
def resolve-initial [piped: any, text: list<string>, brief: any, verbose: bool] {
    if ($text | is-not-empty) {
        return ($text | str join " ")
    }
    if $piped != null {
        let d = $piped | describe
        if ($d | str starts-with "string") { return $piped }
        if $d == "list<string>" { return ($piped | str join "\n") }
        error make {msg: $"polish: pipe input must be text, not ($d) — use `open --raw file` for markdown/structured files"}
    }
    if $brief != null {
        if $verbose { print --stderr $"(ansi attr_dimmed)pass 0: generating draft from brief(ansi reset)" }
        return ($brief | draft)
    }
    error make {msg: "polish: provide text via pipe, argument or --brief"}
}

# Gather findings from every active critic at the current level.
# Returns {findings: [...], warnings: [...]}.
# - findings are auto-fixable and drive the loop.
# - warnings are reported but do not modify the text (factcheck, quotes).
def critique [
    draft: string
    level: string
    lix_min: int
    lix_max: int
    repeat_min_length: int
]: nothing -> record {
    mut findings = []
    mut warnings = []

    # --- Deterministic critics (all levels) ---

    let l = $draft | lix
    if $l.lix > $lix_max {
        $findings = ($findings | append {
            kind: "lix-too-high"
            severity: 2
            instruction: $"The text has Lix ($l.lix); the target is at most ($lix_max). Shorter sentences and more concrete words. Preserve all content and points fully."
            description: $"lix ($l.lix) above ceiling ($lix_max)"
        })
    } else if $l.lix < $lix_min {
        $findings = ($findings | append {
            kind: "lix-too-low"
            severity: 1
            instruction: $"The text has Lix ($l.lix); the target is at least ($lix_min). Greater variation in sentence structure and slightly more precise word choice, but keep the language natural."
            description: $"lix ($l.lix) below floor ($lix_min)"
        })
    }

    let reps = $draft | repeats --min-length $repeat_min_length --min-count 2 --top 5
    for r in $reps {
        $findings = ($findings | append {
            kind: "repeat"
            severity: 1
            instruction: $"The phrase \"($r.value)\" occurs ($r.count) times. Keep at most one occurrence; rewrite the others with varied phrasing that preserves the meaning."
            description: $"repeated phrase: \"($r.value)\" x($r.count)"
        })
    }

    # --- LLM critics (light and up) ---

    if $level in ["light", "editorial", "publication"] {
        let proofed = $draft | proof
        if (normalize $proofed) != (normalize $draft) {
            $findings = ($findings | append {
                kind: "proof"
                severity: 3
                instruction: "proofread"
                description: "spelling/grammar/punctuation corrections"
                replacement: $proofed
            })
        }
    }

    if $level in ["editorial", "publication"] {
        let r = $draft | readability
        let level_line = ($r | lines | first | default "")
        if ($level_line | str downcase | str contains "hard") {
            $findings = ($findings | append {
                kind: "readability"
                severity: 2
                instruction: "Make the language more accessible — shorter sentences, less jargon, more concrete examples. Preserve the points."
                description: $level_line
            })
        }
    }

    # --- Publication level: warnings, not fixes ---

    if $level == "publication" {
        let fc = $draft | factcheck
        if (normalize $fc) != "OK — no errors found" {
            $warnings = ($warnings | append {
                kind: "factcheck"
                description: "potential factual errors"
                body: $fc
            })
        }
        let q = $draft | quotes
        if (normalize $q) != "no quotes found" {
            $warnings = ($warnings | append {
                kind: "quotes"
                description: "quote verification"
                body: $q
            })
        }
    }

    {findings: $findings, warnings: $warnings}
}

# Apply a single fix to the draft. The brief is appended as an anchor
# where relevant.
def apply-fix [draft: string, finding: record, brief: any]: nothing -> string {
    if $finding.kind == "proof" {
        return $finding.replacement
    }
    let anchor = if $brief != null {
        $"\n\nOriginal brief \(preserve the intent faithfully\): ($brief)"
    } else { "" }
    $draft | rw $"($finding.instruction)($anchor)"
}

def normalize [s: string]: nothing -> string {
    $s | str trim
}
