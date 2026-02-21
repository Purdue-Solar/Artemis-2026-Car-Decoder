#!/bin/sh
set -eu

# Constants
NUM_SYNTHETIC_TESTS=100
MESSAGE_COUNT=500
SEED_RETRY_LIMIT=100
TEST_DIR_NAME="Test"
EXPECTED_DIR_NAME="Test_Expected"
GENERATED_DIR_NAME="Test_Generated"
GENERATED_EXPECTED_DIR_NAME="Test_Generated_Expected"
OUT_DIR_NAME="Test_Out"
GENERATED_SEED_FILE_NAME="generated_seeds.txt"
GENERATOR_SCRIPT_NAME="generate_synthetic_12h_500.py"
SYNTHETIC_NAME_PREFIX="synthetic_12h_500_"
DECODER_SOURCE_NAME="decoder.c"
TEST_SOURCE_NAME="test_decoder.c"
OBJ_FILE_NAME="decoder.o"
TEST_BIN_NAME="decoder_test"
OBJ_LIGHT_FILE_NAME="decoder_light.o"
TEST_BIN_LIGHT_NAME="decoder_test_light"
OBJ_MOD_FILE_NAME="decoder_mod.o"
TEST_BIN_MOD_NAME="decoder_test_mod"
OBJ_AGG_FILE_NAME="decoder_agg.o"
TEST_BIN_AGG_NAME="decoder_test_agg"
OPT_FLAG_LIGHT="-O1"
OPT_FLAG_MOD="-O2"
OPT_FLAG_AGG="-O3"

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TEST_DIR="$ROOT_DIR/$TEST_DIR_NAME"
EXPECTED_DIR="$ROOT_DIR/$EXPECTED_DIR_NAME"
GENERATED_DIR="$ROOT_DIR/$GENERATED_DIR_NAME"
GENERATED_EXPECTED_DIR="$ROOT_DIR/$GENERATED_EXPECTED_DIR_NAME"
OUT_DIR="$ROOT_DIR/$OUT_DIR_NAME"
OBJ_FILE="$OUT_DIR/$OBJ_FILE_NAME"
TEST_BIN="$OUT_DIR/$TEST_BIN_NAME"
OBJ_LIGHT_FILE="$OUT_DIR/$OBJ_LIGHT_FILE_NAME"
TEST_BIN_LIGHT="$OUT_DIR/$TEST_BIN_LIGHT_NAME"
OBJ_MOD_FILE="$OUT_DIR/$OBJ_MOD_FILE_NAME"
TEST_BIN_MOD="$OUT_DIR/$TEST_BIN_MOD_NAME"
OBJ_AGG_FILE="$OUT_DIR/$OBJ_AGG_FILE_NAME"
TEST_BIN_AGG="$OUT_DIR/$TEST_BIN_AGG_NAME"

mkdir -p "$OUT_DIR"

USED_SEEDS_FILE="$OUT_DIR/$GENERATED_SEED_FILE_NAME"
> "$USED_SEEDS_FILE"

mkdir -p "$GENERATED_DIR" "$GENERATED_EXPECTED_DIR"
rm -f "$GENERATED_DIR"/*.hex "$GENERATED_EXPECTED_DIR"/*.expected.csv

if [ "$NUM_SYNTHETIC_TESTS" -gt 0 ]; then
  i=0
  while [ "$i" -lt "$NUM_SYNTHETIC_TESTS" ]; do
    seed="$RANDOM"
    attempts=0
    while grep -qx "$seed" "$USED_SEEDS_FILE"; do
      seed="$RANDOM"
      attempts=$((attempts + 1))
      if [ "$attempts" -ge "$SEED_RETRY_LIMIT" ]; then
        # Repopulate with seeds from already-generated files
        > "$USED_SEEDS_FILE"
        for hex_file in "$GENERATED_DIR"/"$SYNTHETIC_NAME_PREFIX"*.hex; do
          if [ -f "$hex_file" ]; then
            # Extract seed from filename (e.g., synthetic_12h_500_12345.hex -> 12345)
            basename_only=$(basename "$hex_file" .hex)
            extracted_seed="${basename_only#$SYNTHETIC_NAME_PREFIX}"
            echo "$extracted_seed" >> "$USED_SEEDS_FILE"
          fi
        done
        attempts=0
      fi
    done
    echo "$seed" >> "$USED_SEEDS_FILE"
    name="$SYNTHETIC_NAME_PREFIX$seed"
    python3 "$TEST_DIR/$GENERATOR_SCRIPT_NAME" \
      "$name" "$seed" \
      --hex-dir "$GENERATED_DIR" \
      --expected-dir "$GENERATED_EXPECTED_DIR"
    i=$((i + 1))
  done
# Compile unoptimized version
fi

clang -I"$ROOT_DIR" -Dmain=decoder_main -c "$ROOT_DIR/$DECODER_SOURCE_NAME" -o "$OBJ_FILE"
clang -I"$ROOT_DIR" "$TEST_DIR/$TEST_SOURCE_NAME" "$OBJ_FILE" -o "$TEST_BIN"

found_hex=false
generated_count=0
generated_start=""
generated_end=""
for HEX_DIR in "$TEST_DIR" "$GENERATED_DIR"; do
  EXPECTED_BASE="$EXPECTED_DIR"
  if [ "$HEX_DIR" = "$GENERATED_DIR" ]; then
    EXPECTED_BASE="$GENERATED_EXPECTED_DIR"
    generated_start=$(python3 - <<'PY'
import time
print(time.time())
PY
)
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
      python3 "$TEST_DIR/hex_to_bin.py" "$HEX_FILE" "$BIN_FILE"
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

    if [ "$HEX_DIR" = "$GENERATED_DIR" ]; then
      generated_count=$((generated_count + 1))
    fi
  done

  if [ "$HEX_DIR" = "$GENERATED_DIR" ]; then
    generated_end=$(python3 - <<'PY'
import time
print(time.time())
PY
)
  fi
done

if [ "$found_hex" = false ]; then
  echo "No .hex files found in $TEST_DIR or $GENERATED_DIR" >&2
  exit 1
fi

if [ -n "$generated_start" ] && [ -n "$generated_end" ] && [ "$generated_count" -gt 0 ]; then
  python3 "$TEST_DIR/benchmark_generated_suite.py" "$generated_start" "$generated_end" "$generated_count" "$MESSAGE_COUNT"

  # Compile Light Optimization (-O1) version and benchmark
  echo ""
  echo "Compiling Light Optimization (-O1)..."
  clang $OPT_FLAG_LIGHT -I"$ROOT_DIR" -Dmain=decoder_main -c "$ROOT_DIR/$DECODER_SOURCE_NAME" -o "$OBJ_LIGHT_FILE"
  clang $OPT_FLAG_LIGHT -I"$ROOT_DIR" "$TEST_DIR/$TEST_SOURCE_NAME" "$OBJ_LIGHT_FILE" -o "$TEST_BIN_LIGHT"

  light_generated_count=0
  light_generated_start=""
  light_generated_end=""

  # Benchmark Light Optimization on generated suite only
  if [ -d "$GENERATED_DIR" ] && [ "$(ls -1 "$GENERATED_DIR" 2>/dev/null | wc -l)" -gt 0 ]; then
    light_generated_start=$(python3 - <<'PY'
import time
print(time.time())
PY
)

    for HEX_FILE in "$GENERATED_DIR"/*.hex; do
      if [ ! -e "$HEX_FILE" ]; then
        continue
      fi

      base_name=$(basename "$HEX_FILE" .hex)
      BIN_FILE="$OUT_DIR/$base_name.bin"
      OUT_FILE="$OUT_DIR/${base_name}_light.csv"
      EXPECTED_FILE="$GENERATED_EXPECTED_DIR/$base_name.expected.csv"

      if [ ! -f "$BIN_FILE" ]; then
        if command -v xxd >/dev/null 2>&1; then
          xxd -r -p "$HEX_FILE" > "$BIN_FILE"
        else
          python3 "$TEST_DIR/hex_to_bin.py" "$HEX_FILE" "$BIN_FILE"
        fi
      fi

      "$TEST_BIN_LIGHT" "$BIN_FILE" "$OUT_FILE"

      if ! cmp -s "$EXPECTED_FILE" "$OUT_FILE"; then
        echo "Output differs from expected for $base_name in Light Optimization version:" >&2
        exit 1
      fi

      light_generated_count=$((light_generated_count + 1))
    done

    light_generated_end=$(python3 - <<'PY'
import time
print(time.time())
PY
)
  fi

  # Compile Moderate Optimization (-O2) version and benchmark
  echo ""
  echo "Compiling Moderate Optimization (-O2)..."
  clang $OPT_FLAG_MOD -I"$ROOT_DIR" -Dmain=decoder_main -c "$ROOT_DIR/$DECODER_SOURCE_NAME" -o "$OBJ_MOD_FILE"
  clang $OPT_FLAG_MOD -I"$ROOT_DIR" "$TEST_DIR/$TEST_SOURCE_NAME" "$OBJ_MOD_FILE" -o "$TEST_BIN_MOD"

  mod_generated_count=0
  mod_generated_start=""
  mod_generated_end=""

  # Benchmark Moderate Optimization on generated suite only
  if [ -d "$GENERATED_DIR" ] && [ "$(ls -1 "$GENERATED_DIR" 2>/dev/null | wc -l)" -gt 0 ]; then
    mod_generated_start=$(python3 - <<'PY'
import time
print(time.time())
PY
)

    for HEX_FILE in "$GENERATED_DIR"/*.hex; do
      if [ ! -e "$HEX_FILE" ]; then
        continue
      fi

      base_name=$(basename "$HEX_FILE" .hex)
      BIN_FILE="$OUT_DIR/$base_name.bin"
      OUT_FILE="$OUT_DIR/${base_name}_mod.csv"
      EXPECTED_FILE="$GENERATED_EXPECTED_DIR/$base_name.expected.csv"

      if [ ! -f "$BIN_FILE" ]; then
        if command -v xxd >/dev/null 2>&1; then
          xxd -r -p "$HEX_FILE" > "$BIN_FILE"
        else
          python3 "$TEST_DIR/hex_to_bin.py" "$HEX_FILE" "$BIN_FILE"
        fi
      fi

      "$TEST_BIN_MOD" "$BIN_FILE" "$OUT_FILE"

      if ! cmp -s "$EXPECTED_FILE" "$OUT_FILE"; then
        echo "Output differs from expected for $base_name in Moderate Optimization version:" >&2
        exit 1
      fi

      mod_generated_count=$((mod_generated_count + 1))
    done

    mod_generated_end=$(python3 - <<'PY'
import time
print(time.time())
PY
)
  fi

  # Compile Aggressive Optimization (-O3) version and benchmark
  echo ""
  echo "Compiling Aggressive Optimization (-O3)..."
  clang $OPT_FLAG_AGG -I"$ROOT_DIR" -Dmain=decoder_main -c "$ROOT_DIR/$DECODER_SOURCE_NAME" -o "$OBJ_AGG_FILE"
  clang $OPT_FLAG_AGG -I"$ROOT_DIR" "$TEST_DIR/$TEST_SOURCE_NAME" "$OBJ_AGG_FILE" -o "$TEST_BIN_AGG"

  agg_generated_count=0
  agg_generated_start=""
  agg_generated_end=""

  # Benchmark Aggressive Optimization on generated suite only
  if [ -d "$GENERATED_DIR" ] && [ "$(ls -1 "$GENERATED_DIR" 2>/dev/null | wc -l)" -gt 0 ]; then
    agg_generated_start=$(python3 - <<'PY'
import time
print(time.time())
PY
)

    for HEX_FILE in "$GENERATED_DIR"/*.hex; do
      if [ ! -e "$HEX_FILE" ]; then
        continue
      fi

      base_name=$(basename "$HEX_FILE" .hex)
      BIN_FILE="$OUT_DIR/$base_name.bin"
      OUT_FILE="$OUT_DIR/${base_name}_agg.csv"
      EXPECTED_FILE="$GENERATED_EXPECTED_DIR/$base_name.expected.csv"

      "$TEST_BIN_AGG" "$BIN_FILE" "$OUT_FILE"

      if ! cmp -s "$EXPECTED_FILE" "$OUT_FILE"; then
        echo "Output differs from expected for $base_name in Aggressive Optimization version:" >&2
        exit 1
      fi

      agg_generated_count=$((agg_generated_count + 1))
    done

    agg_generated_end=$(python3 - <<'PY'
import time
print(time.time())
PY
)
  fi

  # Print comparison benchmark
  if [ -n "$generated_start" ] && [ -n "$generated_end" ] && [ -n "$light_generated_start" ] && [ -n "$light_generated_end" ] && [ -n "$mod_generated_start" ] && [ -n "$mod_generated_end" ] && [ -n "$agg_generated_start" ] && [ -n "$agg_generated_end" ] && [ "$generated_count" -gt 0 ]; then
    python3 "$TEST_DIR/benchmark_optimization_levels.py" "$generated_start" "$generated_end" "$light_generated_start" "$light_generated_end" "$mod_generated_start" "$mod_generated_end" "$agg_generated_start" "$agg_generated_end" "$generated_count" "$MESSAGE_COUNT"
  fi
fi
