# comma · pipeline — kritiker-løkken. Orkestrerer transform, generate og
# analyze til en iterativ refine-flow.
#
# Princip:
#   1. Hvis intet udkast pipes ind men --brief gives, genereres et udkast.
#   2. Hver pass kører deterministiske kritikere (lix, repeats) + valgfri
#      LLM-kritikere (proof, readability) afhængigt af --level.
#   3. Hver finding mappes til en målrettet fix — vi PATCHER, redrafter ikke.
#   4. Briefen vedhæftes som anker mod drift.
#   5. Stop ved: ingen findings · konvergens (hash uændret) · max-passes nået.
#
# Designvalg:
# - Deterministiske kritikere er stop-betingelsen. LLM-kritikere kan finde
#   "issues" i evighed — vi stoler kun på dem så længe de hårde tærskler
#   ikke er nået.
# - factcheck/quotes på publication-level RAPPORTERES, fixes ikke automatisk
#   — de kræver menneskelig dømmekraft.
# - Verbose-log går til stderr så stdout forbliver pipe-rent.

use transform.nu *
use analyze.nu *
use generate.nu *

# Iterativ kritiker-løkke: genererer evt. udkast, analyserer, patcher,
# gentager til konvergens. Returnerer ren tekst på stdout.
#
#   open udkast.md | polish
#   polish --brief "blogpost om espresso-ekstraktion" --verbose
#   open tale.md | polish --level publication --max-passes 3
export def polish [
    --level (-L): string = "editorial"  # light | editorial | publication
    --max-passes: int = 4               # hård cap på iterationer
    --lix-min: int = 30                 # nedre Lix-grænse (under = "for monoton")
    --lix-max: int = 50                 # øvre Lix-grænse (over = "for tung")
    --repeat-min-length: int = 4        # alarm hvis n-gram >= dette gentages
    --brief: string                     # original brief — anker mod drift
    --verbose (-v)                      # log hver pass til stderr
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
            if $verbose { print --stderr $"(ansi green)pass ($pass): clean, stopper(ansi reset)" }
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
            if $verbose { print --stderr $"(ansi yellow)pass ($pass): konvergeret \(hash uændret\), stopper(ansi reset)" }
            break
        }
    }

    if $verbose {
        print --stderr ""
        print --stderr "=== revisionslog ==="
        print --stderr ($log | table)
        if ($warnings | is-not-empty) {
            print --stderr ""
            print --stderr $"(ansi red_bold)=== advarsler \(kræver manuel review\) ===(ansi reset)"
            for w in $warnings {
                print --stderr $"(ansi red)[($w.kind)](ansi reset) ($w.description)"
                print --stderr $w.body
                print --stderr ""
            }
        }
    }

    $draft
}

# Bestem initial tekst: pipe > argument > brief-generering.
def resolve-initial [piped: any, text: list<string>, brief: any, verbose: bool] {
    if ($text | is-not-empty) {
        return ($text | str join " ")
    }
    if $piped != null {
        let d = $piped | describe
        if ($d | str starts-with "string") { return $piped }
        if $d == "list<string>" { return ($piped | str join "\n") }
        error make {msg: $"polish: pipe-input skal være tekst, ikke ($d) — brug `open --raw fil` for markdown/strukturerede filer"}
    }
    if $brief != null {
        if $verbose { print --stderr $"(ansi attr_dimmed)pass 0: genererer udkast fra brief(ansi reset)" }
        return ($brief | draft)
    }
    error make {msg: "polish: angiv tekst via pipe, argument eller --brief"}
}

# Saml findings fra alle aktive kritikere på det aktuelle level.
# Returnerer {findings: [...], warnings: [...]}.
# - findings er auto-fixable og driver løkken.
# - warnings rapporteres men ændrer ikke teksten (factcheck, quotes).
def critique [
    draft: string
    level: string
    lix_min: int
    lix_max: int
    repeat_min_length: int
]: nothing -> record {
    mut findings = []
    mut warnings = []

    # --- Deterministiske kritikere (alle levels) ---

    let l = $draft | lix
    if $l.lix > $lix_max {
        $findings = ($findings | append {
            kind: "lix-too-high"
            severity: 2
            instruction: $"Teksten har Lix ($l.lix), målet er højst ($lix_max). Kortere sætninger og mere konkrete ord. Bevar indhold og pointer fuldt ud."
            description: $"lix ($l.lix) over loft ($lix_max)"
        })
    } else if $l.lix < $lix_min {
        $findings = ($findings | append {
            kind: "lix-too-low"
            severity: 1
            instruction: $"Teksten har Lix ($l.lix), målet er mindst ($lix_min). Større variation i sætningsstruktur og lidt mere præcist ordvalg, men hold sproget naturligt."
            description: $"lix ($l.lix) under gulv ($lix_min)"
        })
    }

    let reps = $draft | repeats --min-length $repeat_min_length --min-count 2 --top 5
    for r in $reps {
        $findings = ($findings | append {
            kind: "repeat"
            severity: 1
            instruction: $"Frasen \"($r.value)\" forekommer ($r.count) gange. Behold højst én forekomst; omskriv de øvrige med varieret formulering der bevarer betydningen."
            description: $"gentaget frase: \"($r.value)\" x($r.count)"
        })
    }

    # --- LLM-kritikere (light og opefter) ---

    if $level in ["light", "editorial", "publication"] {
        let proofed = $draft | proof
        if (normalize $proofed) != (normalize $draft) {
            $findings = ($findings | append {
                kind: "proof"
                severity: 3
                instruction: "korrektur"
                description: "stavning/grammatik/tegnsætning rettet"
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
                instruction: "Gør sproget mere tilgængeligt — kortere sætninger, mindre jargon, mere konkrete eksempler. Bevar pointerne."
                description: $level_line
            })
        }
    }

    # --- Publication-level: warnings, ikke fixes ---

    if $level == "publication" {
        let fc = $draft | factcheck
        if (normalize $fc) != "OK — no errors found" {
            $warnings = ($warnings | append {
                kind: "factcheck"
                description: "potentielle faktuelle fejl"
                body: $fc
            })
        }
        let q = $draft | quotes
        if (normalize $q) != "no quotes found" {
            $warnings = ($warnings | append {
                kind: "quotes"
                description: "citat-verifikation"
                body: $q
            })
        }
    }

    {findings: $findings, warnings: $warnings}
}

# Anvend én fix på et udkast. Briefen vedhæftes som anker hvor relevant.
def apply-fix [draft: string, finding: record, brief: any]: nothing -> string {
    if $finding.kind == "proof" {
        return $finding.replacement
    }
    let anchor = if $brief != null {
        $"\n\nOprindelig brief \(bevar intentet trofast\): ($brief)"
    } else { "" }
    $draft | rw $"($finding.instruction)($anchor)"
}

def normalize [s: string]: nothing -> string {
    $s | str trim
}
