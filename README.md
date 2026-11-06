# hp-smart-tank-mac

Print on an **HP Smart Tank 520/540** connected by USB to an Apple Silicon Mac, where HP ships no macOS driver.

Works as a plain command-line tool and as a [Claude Code](https://claude.com/claude-code) plugin with a `print` skill.

## The problem

The Mac sees the printer over USB, but:

- HP's support site has only firmware for this model, no macOS driver.
- macOS offers only "Generic PCL", which prints nothing useful.
- macOS's AirPrint-over-USB bridge (`ippusbd`) hangs, so "Add Printer" freezes.

## How it works

```
your file ──► PDF ──► rotate landscape pages ──► CUPS raster ──► hpcups ──► PCL3GUI ──► USB
             (Chrome    (portraitize.swift)      (cupsfilter)    (HPLIP)               (usbsend.py)
              or cupsfilter)
```

1. Asked over USB, the printer lists `PCL3GUI` among the languages it speaks.
2. [HPLIP](https://developers.hp.com/hp-linux-imaging-and-printing), HP's open-source Linux driver, has a `hpcups` filter and a PPD for exactly this model. `install.sh` downloads the HPLIP source and builds only `hpcups` for macOS, with a few small shims.
3. `print.sh` turns your file into a page raster and runs it through `hpcups`.
4. `usbsend.py` writes the job straight to the printer's USB printer interface with libusb. This skips the `ippusbd` bridge that hangs. macOS doesn't claim that interface, so no sudo is needed.

## Install

Needs Homebrew, Xcode command line tools, and Python 3.

```bash
git clone https://github.com/dm1tryG/hp-smart-tank-mac
cd hp-smart-tank-mac
./scripts/install.sh
```

This builds everything into `~/.local/share/hp-print` (set `HP_PRINT_PREFIX` to change it). It takes about a minute.

## Print

```bash
~/.local/share/hp-print/print.sh letter.pdf
~/.local/share/hp-print/print.sh page.html --copies 2
~/.local/share/hp-print/print.sh notes.txt --dry   # build the job, don't print
```

PDF, HTML (rendered with headless Google Chrome), text, Word, RTF and images work. Paper is A4.

### As a Claude Code plugin

Add this repo as a plugin. Then ask Claude to "print this" or "make a card and print it", and the `print` skill takes over.

## Limits

- **Black and white only.** In color mode `hpcups` sends empty rows and the sheet comes out blank, so colors print as gray. PRs welcome.
- **No scanner.**
- **Not a system printer.** It doesn't show up in Cmd+P. Print from the command line or through Claude.
- Tested only on one Smart Tank 520 (USB ID `03f0:4554`), MacBook Pro M4, macOS 26.

## License

MIT for this repo. `install.sh` downloads and builds HPLIP, which has its own licenses (mostly GPL-2.0).
