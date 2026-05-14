# comma · convert — convert markdown to other document formats on disk.
#
# This module is for offline file conversion (PDF, HTML, DOCX, EPUB, Typst
# source). For publishing to platforms via API (LinkedIn, Drupal, Medium,
# etc.), see publish.nu.
#
# Dependencies (must be on $PATH):
#   pandoc — universal document converter
#   typst  — modern typesetting (used as the PDF engine for nice typography)
#
# Usage:
#   open article.md | to-pdf article.pdf --title "My article"
#   open article.md | to-html article.html
#   open article.md | to-docx article.docx --author "Lennart Kiil"
#   open article.md | preview              # temp PDF + open in viewer
#   open article.md | pub out.pdf          # generic dispatch by file extension
#
# Design choices:
# - Input is expected to be markdown (or plain text — pandoc swallows both).
# - Always writes to a file (PDF/DOCX are not pipe-friendly).
# - --pdf-engine=typst as the default: faster and prettier than LaTeX.
# - Pipe input via $in; argument text also works (like the other comma files).

def comma-input [piped: any, args: list<string>] {
    let joined = $args | str join " "
    if ($args | is-not-empty) { return $joined }
    if $piped == null {
        error make {msg: "convert: pipe a string in or pass text as an argument"}
    }
    if ($piped | describe) == "string" { return $piped }
    if ($piped | describe) == "list<string>" { return ($piped | str join "\n") }
    error make {msg: $"convert: pipe input must be text, not (($piped | describe)) — use `open --raw file`"}
}

# Verify that an external command is available — fail clearly if not.
def require [cmd: string] {
    if (which $cmd | is-empty) {
        error make {msg: $"convert: '($cmd)' not found in PATH. Install with `brew install ($cmd)`."}
    }
}

# Build pandoc metadata args from title/author/date.
def meta-args [title: any, author: any, date: any]: nothing -> list<string> {
    mut args = []
    if $title != null  { $args = ($args | append ["--metadata" $"title=($title)"]) }
    if $author != null { $args = ($args | append ["--metadata" $"author=($author)"]) }
    if $date != null   { $args = ($args | append ["--metadata" $"date=($date)"]) }
    $args
}

# Markdown → PDF via pandoc, using typst as the default pdf-engine.
#
#   open article.md | to-pdf article.pdf
#   "# Hi\n\nWorld" | to-pdf draft.pdf --title "My draft" --author "LK"
export def to-pdf [
    out: path                  # output file (typically .pdf)
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
    print $"(ansi green)wrote ($out)(ansi reset)"
}

# Markdown → standalone HTML.
#
#   open article.md | to-html article.html
#   open article.md | to-html article.html --css style.css
export def to-html [
    out: path
    --title: string
    --author: string
    --date: string
    --css: path                # external stylesheet
    --template (-t): path
    --no-standalone            # emit a fragment without <html>/<head>
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
    print $"(ansi green)wrote ($out)(ansi reset)"
}

# Markdown → DOCX.
#
#   open minutes.md | to-docx minutes.docx --author "LK"
export def to-docx [
    out: path
    --title: string
    --author: string
    --date: string
    --reference-doc: path      # docx template with custom styles
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
    print $"(ansi green)wrote ($out)(ansi reset)"
}

# Markdown → EPUB.
#
#   open book.md | to-epub book.epub --title "My book" --author "LK"
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
    print $"(ansi green)wrote ($out)(ansi reset)"
}

# Markdown → Typst source (.typ). Useful when you want to tweak typst
# syntax manually before compiling.
#
#   open article.md | to-typst article.typ
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
    print $"(ansi green)wrote ($out)(ansi reset)"
}

# Compile an existing .typ file to PDF via typst directly (no pandoc).
#
#   typst-compile article.typ article.pdf
export def typst-compile [
    input: path                # .typ source file
    output: path               # .pdf output file
    --root: path               # root directory for include-relative paths
] {
    require typst
    mut args = ["compile" $input $output]
    if $root != null { $args = ($args | append ["--root" $root]) }
    ^typst ...$args
    print $"(ansi green)wrote ($output)(ansi reset)"
}

# Render to a temporary PDF and open in the system default app
# (Preview on macOS). No permanent file left behind — perfect for a
# quick visual check.
#
#   open draft.md | preview
#   open draft.md | preview --title "Draft v3"
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
    print $"(ansi attr_dimmed)\(temp: ($tmp)\)(ansi reset)"
}

# Generic dispatch: picks the format from the output file extension.
# (Kept as `pub` for backwards compatibility — the name originates from
# when this module was called `publish`.)
#
#   open article.md | pub out.pdf
#   open article.md | pub out.html
#   open article.md | pub out.docx --author "LK"
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
        _ => (error make {msg: $"convert: unknown extension '($ext)' — use pdf, html, docx, epub or typ"})
    }
}

# --- from-* commands: convert other formats INTO markdown ---

# Helper for text-format from-* commands: read from pipe or from a file path.
def from-text [piped: any, file: any] {
    if $file != null { return (open --raw $file) }
    if $piped == null {
        error make {msg: "from-*: pipe text in or pass a file path"}
    }
    if ($piped | describe) == "string" { return $piped }
    if ($piped | describe) == "list<string>" { return ($piped | str join "\n") }
    error make {msg: $"from-*: pipe input must be text, not (($piped | describe))"}
}

# HTML → markdown. Accepts a file path or piped HTML.
#
#   open --raw page.html | from-html
#   from-html page.html
export def from-html [
    file?: path                # input .html file (optional if piping HTML in)
    --wrap (-w): string = "none"  # pandoc --wrap setting
] {
    require pandoc
    let piped = $in
    let src = from-text $piped $file
    $src | ^pandoc --from html --to markdown --wrap $wrap
}

# LaTeX → markdown.
#
#   open --raw paper.tex | from-latex
#   from-latex paper.tex
export def from-latex [
    file?: path
    --wrap (-w): string = "none"
] {
    require pandoc
    let piped = $in
    let src = from-text $piped $file
    $src | ^pandoc --from latex --to markdown --wrap $wrap
}

# reStructuredText → markdown.
#
#   from-rst manual.rst
export def from-rst [
    file?: path
    --wrap (-w): string = "none"
] {
    require pandoc
    let piped = $in
    let src = from-text $piped $file
    $src | ^pandoc --from rst --to markdown --wrap $wrap
}

# Org-mode → markdown.
#
#   from-org notes.org
export def from-org [
    file?: path
    --wrap (-w): string = "none"
] {
    require pandoc
    let piped = $in
    let src = from-text $piped $file
    $src | ^pandoc --from org --to markdown --wrap $wrap
}

# DOCX → markdown. Word documents are binary; input must come from a file path.
#
#   from-docx report.docx
#   from-docx report.docx --extract-media ./figures
export def from-docx [
    file: path                 # input .docx file
    --wrap (-w): string = "none"
    --extract-media: path      # directory to write embedded images into
] {
    require pandoc
    mut args = [--from docx --to markdown --wrap $wrap]
    if $extract_media != null { $args = ($args | append ["--extract-media" $extract_media]) }
    $args = ($args | append $file)
    ^pandoc ...$args
}

# EPUB → markdown.
#
#   from-epub book.epub
#   from-epub book.epub --extract-media ./illustrations
export def from-epub [
    file: path
    --wrap (-w): string = "none"
    --extract-media: path
] {
    require pandoc
    mut args = [--from epub --to markdown --wrap $wrap]
    if $extract_media != null { $args = ($args | append ["--extract-media" $extract_media]) }
    $args = ($args | append $file)
    ^pandoc ...$args
}

# ODT (LibreOffice/OpenOffice) → markdown.
#
#   from-odt document.odt
export def from-odt [
    file: path
    --wrap (-w): string = "none"
    --extract-media: path
] {
    require pandoc
    mut args = [--from odt --to markdown --wrap $wrap]
    if $extract_media != null { $args = ($args | append ["--extract-media" $extract_media]) }
    $args = ($args | append $file)
    ^pandoc ...$args
}

# PDF → plain text via pdftotext (poppler). Pandoc cannot read PDF directly,
# so the output is plain text, not true markdown — headings, tables and
# columns may not survive. Still useful for downstream analyze/polish/etc.
#
# Dependency: `pdftotext` (from poppler — `brew install poppler`).
#
#   from-pdf paper.pdf
#   from-pdf paper.pdf --layout       # preserve original column layout
export def from-pdf [
    file: path
    --layout                   # preserve original layout (pdftotext -layout)
] {
    require pdftotext
    let layout_arg = if $layout { ["-layout"] } else { [] }
    ^pdftotext ...$layout_arg $file -
}
