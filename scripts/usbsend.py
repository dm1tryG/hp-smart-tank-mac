"""Send a print job (PCL) to the HP Smart Tank 520/540 over its legacy USB printer interface.

macOS's ippusbd claims the IPP-over-USB interfaces (protocol 4), but leaves the
bidirectional printer interface (class 7, protocol 2) free, so we write there.
"""
import sys

import usb.backend.libusb1
import usb.core
import usb.util

HP_VENDOR = 0x03F0
SMART_TANK_520_540 = 0x4554
LIBUSB = ["/opt/homebrew/lib/libusb-1.0.dylib", "/usr/local/lib/libusb-1.0.dylib"]
CHUNK = 16384


def find_backend():
    for path in LIBUSB:
        backend = usb.backend.libusb1.get_backend(find_library=lambda _: path)
        if backend:
            return backend
    sys.exit("libusb not found: brew install libusb")


def main(job_path):
    dev = usb.core.find(idVendor=HP_VENDOR, idProduct=SMART_TANK_520_540, backend=find_backend())
    if dev is None:
        sys.exit("printer not found on USB: is it on and plugged in?")
    intf = next(
        (i for i in dev.get_active_configuration()
         if i.bInterfaceClass == 7 and i.bInterfaceProtocol == 2),
        None,
    )
    if intf is None:
        sys.exit("printer has no free bidirectional USB printer interface")
    usb.util.claim_interface(dev, intf.bInterfaceNumber)
    try:
        ep = usb.util.find_descriptor(
            intf,
            custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_OUT,
        )
        data = open(job_path, "rb").read()
        sent = sum(ep.write(data[i:i + CHUNK], timeout=30000) for i in range(0, len(data), CHUNK))
        print(f"sent {sent} of {len(data)} bytes")
    finally:
        usb.util.release_interface(dev, intf.bInterfaceNumber)


if __name__ == "__main__":
    main(sys.argv[1])
