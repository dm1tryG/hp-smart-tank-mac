#!/bin/bash
# Build the HPLIP hpcups filter for macOS (arm64) and set up the print tools in ~/.local/share/hp-print.
# No sudo needed. Needs Homebrew and Xcode command line tools.
set -euo pipefail

HPLIP_VERSION=3.26.6
HPLIP_URL="https://downloads.sourceforge.net/project/hplip/hplip/$HPLIP_VERSION/hplip-$HPLIP_VERSION.tar.gz"
PREFIX="${HP_PRINT_PREFIX:-$HOME/.local/share/hp-print}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Homebrew packages"
brew list libusb >/dev/null 2>&1 || brew install libusb
brew list jpeg-turbo >/dev/null 2>&1 || brew install jpeg-turbo
JPEG="$(brew --prefix jpeg-turbo)"

echo "==> Downloading HPLIP $HPLIP_VERSION"
curl -fsSL -o "$WORK/hplip.tar.gz" "$HPLIP_URL"
tar -xzf "$WORK/hplip.tar.gz" -C "$WORK"
SRC="$WORK/hplip-$HPLIP_VERSION"

echo "==> Building hpcups"
# macOS has no <malloc.h>.
mkdir -p "$WORK/shim" "$WORK/obj"
echo '#include <stdlib.h>' > "$WORK/shim/malloc.h"
# Only the LaserJet JetReady path calls these; this printer speaks PCL3GUI, so they must never run.
printf '#include <stdlib.h>\nvoid hp_rgb_ycc_setup(void){abort();}\nvoid jpeg_buffer_dest(void){abort();}\n' > "$WORK/shim/stubs.c"

# -include common/utils.h: on a case-insensitive filesystem "utils.h" resolves to prnt/hpcups/Utils.h.
FLAGS=(-O2 -w -DDISABLE_IMAGEPROCESSOR -DAPDK_LITTLE_ENDIAN '-DCONFDIR="/etc/hp"'
       -I"$WORK/shim" -I. -Iio/hpmud -Iprnt/hpcups -I"$JPEG/include" -include common/utils.h)
# jccolor.c / jdatadbf.c need libjpeg internals and only serve the JetReady path too.
SOURCES=$(cd "$SRC" && awk '/^hpcups_SOURCES/,/ImageProcessor.h$/' Makefile.am | tr ' \\\t' '\n\n\n' \
          | grep -E '\.(cpp|c)$' | grep -v -e jccolor -e jdatadbf | sort -u)
OBJS=()
for f in $SOURCES; do
  o="$WORK/obj/$(echo "$f" | tr / _).o"
  case "$f" in
    *.c) (cd "$SRC" && cc -c "${FLAGS[@]}" "$f" -o "$o") ;;
    *)   (cd "$SRC" && c++ -c -std=gnu++11 "${FLAGS[@]}" "$f" -o "$o") ;;
  esac
  OBJS+=("$o")
done
cc -c "$WORK/shim/stubs.c" -o "$WORK/obj/stubs.o"

mkdir -p "$PREFIX"
c++ -o "$PREFIX/hpcups" "${OBJS[@]}" "$WORK/obj/stubs.o" -L"$JPEG/lib" -ljpeg -lcups -lz
# Bundle libjpeg next to the filter so it runs without Homebrew paths (e.g. under CUPS).
cp "$JPEG/lib/libjpeg.8.dylib" "$PREFIX/"
chmod u+w "$PREFIX/libjpeg.8.dylib"
install_name_tool -change "$(otool -L "$PREFIX/hpcups" | awk '/libjpeg/{print $1}')" @loader_path/libjpeg.8.dylib "$PREFIX/hpcups"
install_name_tool -id @loader_path/libjpeg.8.dylib "$PREFIX/libjpeg.8.dylib"
codesign -s - -f "$PREFIX/libjpeg.8.dylib" "$PREFIX/hpcups" 2>/dev/null

echo "==> PPD (A4, black and white by default)"
gzcat "$SRC/ppd/hpcups/hp-smart_tank_520_540_series.ppd.gz" | sed -E \
  -e 's/^\*DefaultColorModel: RGB/*DefaultColorModel: KGray/' \
  -e 's/^\*Default(PageSize|PageRegion|ImageableArea|PaperDimension): Letter/*Default\1: A4/' \
  > "$PREFIX/hp-smart_tank_520_540.ppd"

echo "==> Helpers"
swiftc -O "$HERE/portraitize.swift" -o "$PREFIX/portraitize"
cp "$HERE/usbsend.py" "$HERE/print.sh" "$PREFIX/"
chmod +x "$PREFIX/print.sh"
python3 -m venv "$PREFIX/venv"
"$PREFIX/venv/bin/pip" -q install pyusb

echo "Done. Print with: $PREFIX/print.sh FILE"
