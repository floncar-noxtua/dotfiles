---
name: noxtua-slides
description: "Draft a slide deck as a plain slides.md, iterate on it in chat, then build it as a claude.ai Slides artifact with Noxtua branding: logo and imagery from the org's default Noxtua Design System, colours and type from the noxtua-presentations PPTX template. Use when the user wants slides, a deck or a presentation as a Slides artifact or link rather than a .pptx file, or says 'noxtua slides', 'draft slides in markdown' or 'build the deck from slides.md'. Not for a .pptx deliverable built from the official template: use noxtua-presentations for that."
---

# Noxtua slides

Two phases: draft in Markdown, then build once as a Slides artifact.

## 1. Draft: `slides.md`

- One folder per deck, `~/Code/notes/slides/<deck-name>/` unless the user names another: `slides.md`, `img/` for pictures, `diagrams/` for Mermaid sources (`*.mmd`).
- `slides.md` holds content only: `---` between slides, a `#` title per slide, bullets, `![](img/x.png)` for pictures, `![](diagrams/x.mmd)` for diagrams. It is never rendered, so no Marp or Slidev syntax is needed.
- Iterate by editing the file in place. Keep titles short (1–4 words, sentence case, no full stop); split a slide rather than crowd it.
- Do not build the artifact until the user says the draft is final.

## 2. Build: Slides artifact

1. Run Artifact `quickstart` with intent `slides` and follow it to create the deck from the Slides type, using the org's default **Noxtua Design System** it names.
2. From that design system take **only the logo and imagery**: `assets/logo/` (full lockup and signet) and its illustrations. Read the cards you need from the design system with Artifact `read`.
3. From the **`noxtua-presentations`** skill take **only colours and type**: load it and apply its "Brand rules" section, i.e. the Colors table (and chart series order) and the Typography rules. Where they conflict with the design system's colours or type, the PPTX rules win.
4. Do **not** carry over anything else from `noxtua-presentations`: no template layouts, marble or architecture photos, waves, rings or edge strips, and no PPTX tooling. They cannot be reproduced exactly in an artifact.
5. Pictures from `img/` are uploaded as artifact assets. Mermaid diagrams are rendered to SVG (`npx -y @mermaid-js/mermaid-cli -i diagrams/x.mmd -o diagrams/x.svg`), themed with the PPTX palette, and uploaded the same way, unless the Slides type's own instructions offer native diagrams.
6. Read brand values from the two sources each time. Never copy hex codes or font sizes into this skill or the deck folder: both sources are maintained by others and change.
