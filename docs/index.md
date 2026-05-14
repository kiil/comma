---
title: Home
layout: home
nav_order: 1
permalink: /
---

# comma documentation

Documentation here follows the [Diátaxis framework](https://diataxis.fr/), which separates docs by the user's intent:

| Quadrant | When you are… | Read… |
|---|---|---|
| [Tutorials](tutorials/) | learning the tool from scratch | step-by-step walkthroughs that get you a working result |
| [How-to guides](how-to/) | trying to solve a specific problem | task-focused recipes that assume basics |
| [Reference](reference/) | looking up exact command behaviour | dry, complete descriptions of every flag |
| [Explanation](explanation/) | trying to understand a design choice | discussions of *why* things are the way they are |

If you are new, start with [Getting started](tutorials/01-getting-started.md). If you know the basics and want to do a specific job, jump into [how-to](how-to/). If you want to look up a command, [reference](reference/) is exhaustive. If you want to understand the design, [explanation](explanation/) is the discussion track.

## Sitemap

### Tutorials

- [01 — Getting started](tutorials/01-getting-started.md)
- [02 — The research-to-publish pipeline](tutorials/02-the-research-pipeline.md)

### How-to guides

- [Proofread a document](how-to/proofread-a-document.md)
- [Ground generation in research notes](how-to/ground-generation-in-research.md)
- [Analyze text statistically](how-to/analyze-text-statistically.md)
- [Iteratively polish a draft](how-to/polish-a-draft.md)
- [Render to PDF via typst](how-to/render-to-pdf.md)
- [Convert documents into markdown](how-to/convert-into-markdown.md)
- [Switch LLM models](how-to/switch-llm-models.md)

### Reference

- [transform](reference/transform.md) — rewrite existing text
- [generate](reference/generate.md) — produce new text from a brief
- [analyze](reference/analyze.md) — inspect text (deterministic + LLM NLP)
- [validate](reference/validate.md) — verify text against reality
- [research](reference/research.md) — capture, distill, IWE bridge
- [pipeline](reference/pipeline.md) — polish (critic loop)
- [convert](reference/convert.md) — convert markdown to/from PDF, HTML, DOCX, EPUB and other formats
- [publish](reference/publish.md) — reserved for platform-publishing APIs
- [configuration](reference/configuration.md) — env vars and model overrides

### Explanation

- [Design principles](explanation/design-principles.md)
- [The critic loop](explanation/the-critic-loop.md)
- [Deterministic vs. LLM](explanation/deterministic-vs-llm.md)
- [Why IWE for note persistence](explanation/why-iwe.md)
- [Appendix: NLP concepts behind analyze](explanation/appendix-nlp-concepts.md)
