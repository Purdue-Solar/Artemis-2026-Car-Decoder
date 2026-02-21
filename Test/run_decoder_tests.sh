#!/bin/sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TEST_DIR="$ROOT_DIR/Test"
EXPECTED_DIR="$ROOT_DIR/Test_Expected"
GENERATED_DIR="$ROOT_DIR/Test_Generated"
GENERATED_EXPECTED_DIR="$ROOT_DIR/Test_Generated_Expected"
OUT_DIR="$ROOT_DIR/Test_Out"
NUM_SYNTHETIC_TESTS=100

OBJ_FILE="$OUT_DIR/decoder.o"
TEST_BIN="$OUT_DIR/decoder_test"

mkdir -p "$OUT_DIR"

mkdir -p "$GENERATED_DIR" "$GENERATED_EXPECTED_DIR"
rm -f "$GENERATED_DIR"/*.hex "$GENERATED_EXPECTED_DIR"/*.expected.csv

if [ "$NUM_SYNTHETIC_TESTS" -gt 0 ]; then
  i=0
  while [ "$i" -lt "$NUM_SYNTHETIC_TESTS" ]; do
    name="synthetic_12h_500_$i"
    python3 "$TEST_DIR/generate_synthetic_12h_500.py" \
      "$name" "$i" \
      --hex-dir "$GENERATED_DIR" \
      --expected-dir "$GENERATED_EXPECTED_DIR"
    i=$((i + 1))
  done
fi

cc -I"$ROOT_DIR" -Dmain=decoder_main -c "$ROOT_DIR/decoder.c" -o "$OBJ_FILE"
cc -I"$ROOT_DIR" "$TEST_DIR/test_decoder.c" "$OBJ_FILE" -o "$TEST_BIN"

found_hex=false
for HEX_DIR in "$TEST_DIR" "$GENERATED_DIR"; do
  EXPECTED_BASE="$EXPECTED_DIR"
  if [ "$HEX_DIR" = "$GENERATED_DIR" ]; then
    EXPECTED_BASE="$GENERATED_EXPECTED_DIR"
  fi

  for HEX_FILE in "$HEX_DIR"/*.hex; do
    if [ ! -e "$HEX_FILE" ]; then
      continue
    fi

    found_hex=true
    base_name=$(basename "$HEX_FILE" .hex)
    BIN_FILE="$OUT_DIR/$base_name.bin"
    OUT_FILE="$OUT_DIR/$base_name.csv"
    EXPECTED_FILE="$EXPECTED_BASE/$base_name.expected.csv"

    if [ ! -f "$EXPECTED_FILE" ]; then
      echo "Missing expected output: $EXPECTED_FILE" >&2
      exit 1
    fi

    if command -v xxd >/dev/null 2>&1; then
      xxd -r -p "$HEX_FILE" > "$BIN_FILE"
    else
      python3 - "$HEX_FILE" "$BIN_FILE" <<'PY'
import sys

hex_path, bin_path = sys.argv[1], sys.argv[2]
with open(hex_path, "r", encoding="ascii") as f:
    hex_text = "".join(f.read().split())

if len(hex_text) % 2 != 0:
    raise SystemExit("Hex input has odd length")

with open(bin_path, "wb") as out:
    out.write(bytes.fromhex(hex_text))
PY
    fi

    "$TEST_BIN" "$BIN_FILE" "$OUT_FILE"

    if ! cmp -s "$EXPECTED_FILE" "$OUT_FILE"; then
      echo "Output differs from expected for $base_name:" >&2
      echo "Red is expected" >&2
      echo "Green is actual" >&2
      git diff --no-index -- "$EXPECTED_FILE" "$OUT_FILE" || true
      exit 1
    fi

    echo "OK: $base_name"
  done
done

if [ "$found_hex" = false ]; then
  echo "No .hex files found in $TEST_DIR or $GENERATED_DIR" >&2
  exit 1
fi
