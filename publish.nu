# comma · publish — konvertér markdown til publicerbare formater.
#
# Dependencies (skal være i $PATH):
#   pandoc — universal document converter
#   typst  — moderne typesetting (bruges som PDF-engine for smuk typografi)
#
# Brug:
#   open artikel.md | to-pdf artikel.pdf --title "Min artikel"
#   open artikel.md | to-html artikel.html
#   open artikel.md | to-docx artikel.docx --author "Lennart Kiil"
#   open artikel.md | preview              # tmp PDF + åbn i Preview
#   open artikel.md | publish out.pdf      # generisk dispatch via filendelse
#
# Designvalg:
# - Input forventes at være markdown (eller plain tekst — pandoc spiser begge).
# - Skrives altid til fil (PDF/DOCX er ikke pipe-venlige).
# - --pdf-engine=typst som default for PDF: hurtigere og smukkere end LaTeX.
# - Pipe-input via $in; argument-text fungerer også (som de andre comma-filer).

def comma-input [piped: any, args: list<string>] {
    let joined = $args | str join " "
    if ($args | is-not-empty) { return $joined }
    if $piped == null {
        error make {msg: "publish: pipe en streng ind eller giv tekst som argument"}
    }
    if ($piped | describe) == "string" { return $piped }
    if ($piped | describe) == "list<string>" { return ($piped | str join "\n") }
    error make {msg: $"publish: pipe-input skal være tekst, ikke (($piped | describe)) — brug `open --raw fil`"}
}

# Verificér at en ekstern kommando er tilgængelig — fejler klart hvis ikke.
def require [cmd: string] {
    if (which $cmd | is-empty) {
        error make {msg: $"publish: '($cmd)' ikke fundet i PATH. Installer med `brew install ($cmd)`."}
    }
}

# Saml pandoc metadata-args fra title/author/date.
def meta-args [title: any, author: any, date: any]: nothing -> list<string> {
    mut args = []
    if $title != null  { $args = ($args | append ["--metadata" $"title=($title)"]) }
    if $author != null { $args = ($args | append ["--metadata" $"author=($author)"]) }
    if $date != null   { $args = ($args | append ["--metadata" $"date=($date)"]) }
    $args
}

# Markdown → PDF via pandoc, med typst som default pdf-engine.
#
#   open artikel.md | to-pdf artikel.pdf
#   "# Hej\n\nVerden" | to-pdf udkast.pdf --title "Mit udkast" --author "LK"
export def to-pdf [
    out: path                  # outputfil (typisk .pdf)
    --title: string
    --author: string
    --date: string
    --template (-t): path      # pandoc/typst template
    --engine (-e): string = "typst"  # typst | xelatex | pdflatex | weasyprint
    ...text: string
] {
    require pandoc
    if $engine == "typst" { require typst }
    let piped = $in
    let src = comma-input $piped $text
    mut args = [
        --from markdown
        --to pdf
        --pdf-engine $engine
        --output $out
    ]
    $args = ($args | append (meta-args $title $author $date))
    if $template != null { $args = ($args | append ["--template" $template]) }
    $src | ^pandoc ...$args
    print $"(ansi green)skrev ($out)(ansi reset)"
}

# Markdown → standalone HTML.
#
#   open artikel.md | to-html artikel.html
#   open artikel.md | to-html artikel.html --css style.css
export def to-html [
    out: path
    --title: string
    --author: string
    --date: string
    --css: path                # ekstern stylesheet
    --template (-t): path
    --no-standalone            # uddrag-fragment uden <html>/<head>
    ...text: string
] {
    require pandoc
    let piped = $in
    let src = comma-input $piped $text
    mut args = [
        --from markdown
        --to html5
        --output $out
    ]
    if not $no_standalone { $args = ($args | append ["--standalone"]) }
    $args = ($args | append (meta-args $title $author $date))
    if $css != null { $args = ($args | append ["--css" $css]) }
    if $template != null { $args = ($args | append ["--template" $template]) }
    $src | ^pandoc ...$args
    print $"(ansi green)skrev ($out)(ansi reset)"
}

# Markdown → DOCX.
#
#   open referat.md | to-docx referat.docx --author "LK"
export def to-docx [
    out: path
    --title: string
    --author: string
    --date: string
    --reference-doc: path      # docx skabelon med custom styles
    ...text: string
] {
    require pandoc
    let piped = $in
    let src = comma-input $piped $text
    mut args = [
        --from markdown
        --to docx
        --output $out
    ]
    $args = ($args | append (meta-args $title $author $date))
    if $reference_doc != null { $args = ($args | append ["--reference-doc" $reference_doc]) }
    $src | ^pandoc ...$args
    print $"(ansi green)skrev ($out)(ansi reset)"
}

# Markdown → EPUB.
#
#   open bog.md | to-epub bog.epub --title "Min bog" --author "LK"
export def to-epub [
    out: path
    --title: string
    --author: string
    --date: string
    --cover-image: path
    --css: path
    ...text: string
] {
    require pandoc
    let piped = $in
    let src = comma-input $piped $text
    mut args = [
        --from markdown
        --to epub3
        --output $out
    ]
    $args = ($args | append (meta-args $title $author $date))
    if $cover_image != null { $args = ($args | append ["--epub-cover-image" $cover_image]) }
    if $css != null { $args = ($args | append ["--css" $css]) }
    $src | ^pandoc ...$args
    print $"(ansi green)skrev ($out)(ansi reset)"
}

# Markdown → Typst-kildekode (.typ). Nyttig hvis du vil tweake typst-syntaks
# manuelt før kompilering.
#
#   open artikel.md | to-typst artikel.typ
export def to-typst [
    out: path
    --title: string
    --author: string
    --date: string
    ...text: string
] {
    require pandoc
    let piped = $in
    let src = comma-input $piped $text
    mut args = [
        --from markdown
        --to typst
        --output $out
    ]
    $args = ($args | append (meta-args $title $author $date))
    $src | ^pandoc ...$args
    print $"(ansi green)skrev ($out)(ansi reset)"
}

# Kompilér en eksisterende .typ-fil til PDF via typst direkte (uden pandoc).
#
#   typst-compile artikel.typ artikel.pdf
export def typst-compile [
    input: path                # .typ kildefil
    output: path               # .pdf outputfil
    --root: path               # root-mappe for include-relative stier
] {
    require typst
    mut args = ["compile" $input $output]
    if $root != null { $args = ($args | append ["--root" $root]) }
    ^typst ...$args
    print $"(ansi green)skrev ($output)(ansi reset)"
}

# Render til midlertidig PDF og åbn i systemets default-app (Preview på macOS).
# Ingen permanent fil tilbage — perfekt til hurtigt udseende-tjek.
#
#   open udkast.md | preview
#   open udkast.md | preview --title "Udkast v3"
export def preview [
    --title: string
    --author: string
    --engine (-e): string = "typst"
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let tmp = mktemp --tmpdir --suffix .pdf
    $src | to-pdf $tmp --title $title --author $author --engine $engine
    ^open $tmp
    print $"(ansi attr_dimmed)\(midlertidig: ($tmp)\)(ansi reset)"
}

# Generisk dispatch: vælger format baseret på output-filens extension.
# (Hedder `pub` fordi nu-moduler ikke må eksportere kommando med samme
# navn som modulet selv.)
#
#   open artikel.md | pub ud.pdf
#   open artikel.md | pub ud.html
#   open artikel.md | pub ud.docx --author "LK"
export def pub [
    out: path
    --title: string
    --author: string
    --date: string
    --template (-t): path
    --engine: string = "typst"
    ...text: string
] {
    let piped = $in
    let src = comma-input $piped $text
    let ext = $out | path parse | get extension | str downcase
    match $ext {
        "pdf"  => ($src | to-pdf $out --title $title --author $author --date $date --template $template --engine $engine)
        "html" => ($src | to-html $out --title $title --author $author --date $date --template $template)
        "htm"  => ($src | to-html $out --title $title --author $author --date $date --template $template)
        "docx" => ($src | to-docx $out --title $title --author $author --date $date)
        "epub" => ($src | to-epub $out --title $title --author $author --date $date)
        "typ"  => ($src | to-typst $out --title $title --author $author --date $date)
        _ => (error make {msg: $"publish: ukendt extension '($ext)' — brug pdf | html | docx | epub | typ"})
    }
}
