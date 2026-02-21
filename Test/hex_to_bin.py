#!/usr/bin/env python3
"""Convert hex file to binary file."""
import sys

hex_path, bin_path = sys.argv[1], sys.argv[2]
with open(hex_path, "r", encoding="ascii") as f:
    hex_text = "".join(f.read().split())

if len(hex_text) % 2 != 0:
    raise SystemExit("Hex input has odd length")

with open(bin_path, "wb") as out:
    out.write(bytes.fromhex(hex_text))
