---
name: print
description: Print a file (PDF, HTML, text, Word, image) on an HP Smart Tank 520/540 connected to the Mac by USB, through a self-built HPLIP driver. Use when the user says /print, "print this", or asks to make and print a page, letter or card.
---

# print

Prints on an HP Smart Tank 520/540 over USB with HPLIP's `hpcups` filter built for macOS. Tools live in `~/.local/share/hp-print/`.

## Setup (once)

If `~/.local/share/hp-print/print.sh` is missing, run `scripts/install.sh` from this plugin (no sudo, ~1 min). It needs Homebrew and the Xcode command line tools.

## Print

```bash
~/.local/share/hp-print/print.sh FILE [--copies N] [--dry]
```

- PDF prints as is. `.html` is rendered with headless Google Chrome. Other files (txt, docx, rtf, png, jpg) go through `cupsfilter`.
- Landscape pages are rotated onto portrait A4 automatically.
- `--dry` builds the job without printing and prints the page count. Use it first for long documents.
- Before printing a page you made, render a preview (`qlmanage -t -s 1200 -o DIR file.pdf`) and look at it.

## Making a page

Write HTML and print the `.html` file. Set margins and orientation with CSS: `@page { size: A4 landscape; margin: 2cm; }`. Emoji work with `font-family: Georgia, "Apple Color Emoji", serif`. The printer can't print to the edge, so keep ~4 mm free.

## Limits

- Black and white only: color mode gives blank pages, so colors print as gray.
- No scanner.
- If the printer isn't found, it's off or unplugged.
