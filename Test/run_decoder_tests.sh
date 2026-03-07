#!/bin/bash
set -eu

# Parse command line arguments
QUIET=0
for arg in "$@"; do
  if [ "$arg" = "--quiet" ] || [ "$arg" = "-q" ]; then
    QUIET=1
  fi
done

# Constants
NUM_SYNTHETIC_TESTS=10
MESSAGE_COUNT=500
MESSAGE_SIZE_BYTES=19
SEED_RETRY_LIMIT=100
THREADS=4
TEST_DIR_NAME="Test"
EXPECTED_DIR_NAME="Test_Expected"
GENERATED_DIR_NAME="Test_Generated"
GENERATED_EXPECTED_DIR_NAME="Test_Generated_Expected"
OUT_DIR_NAME="Test_Out"
GENERATED_SEED_FILE_NAME="generated_seeds.txt"
GENERATOR_SCRIPT_NAME="generate_synthetic_12h_500.py"
SYNTHETIC_NAME_PREFIX="synthetic_12h_500_"
DECODER_SOURCE_NAME="src/decoder.c"
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

root_path() {
  local relative_path="${1#./}"
  relative_path="${relative_path#/}"
  echo "$ROOT_DIR/$relative_path"
}

TEST_DIR=$(root_path "$TEST_DIR_NAME")
EXPECTED_DIR=$(root_path "$EXPECTED_DIR_NAME")
GENERATED_DIR=$(root_path "$GENERATED_DIR_NAME")
GENERATED_EXPECTED_DIR=$(root_path "$GENERATED_EXPECTED_DIR_NAME")
OUT_DIR=$(root_path "$OUT_DIR_NAME")
DECODER_SOURCE_PATH=$(root_path "$DECODER_SOURCE_NAME")
TEST_SOURCE_PATH=$(root_path "$TEST_DIR_NAME/$TEST_SOURCE_NAME")
GENERATOR_SCRIPT_PATH=$(root_path "$TEST_DIR_NAME/$GENERATOR_SCRIPT_NAME")

DECODER_SOURCE_DIR=$(dirname "$DECODER_SOURCE_PATH")
CLANG_INCLUDE_FLAGS=(-I"$ROOT_DIR" -I"$DECODER_SOURCE_DIR")
OBJ_FILE="$OUT_DIR/$OBJ_FILE_NAME"
TEST_BIN="$OUT_DIR/$TEST_BIN_NAME"
OBJ_LIGHT_FILE="$OUT_DIR/$OBJ_LIGHT_FILE_NAME"
TEST_BIN_LIGHT="$OUT_DIR/$TEST_BIN_LIGHT_NAME"
OBJ_MOD_FILE="$OUT_DIR/$OBJ_MOD_FILE_NAME"
TEST_BIN_MOD="$OUT_DIR/$TEST_BIN_MOD_NAME"
OBJ_AGG_FILE="$OUT_DIR/$OBJ_AGG_FILE_NAME"
TEST_BIN_AGG="$OUT_DIR/$TEST_BIN_AGG_NAME"

if [ ! -f "$DECODER_SOURCE_PATH" ]; then
  log_always "ERROR: Decoder source not found at $DECODER_SOURCE_PATH"
  exit 1
fi

if [ ! -f "$TEST_SOURCE_PATH" ]; then
  log_always "ERROR: Test source not found at $TEST_SOURCE_PATH"
  exit 1
fi

if [ ! -f "$GENERATOR_SCRIPT_PATH" ]; then
  log_always "ERROR: Generator script not found at $GENERATOR_SCRIPT_PATH"
  exit 1
fi

# Logging helper
log() {
  if [ "$QUIET" -eq 0 ]; then
    echo "$@"
  fi
}

log_always() {
  echo "$@"
}

# Wait until number of running background jobs is below THREADS
wait_for_slot() {
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$THREADS" ]; do
    sleep 0.05
  done
}

# Wait for all background jobs
wait_for_all_jobs() {
  wait
}

# ============================================================================
# STEP 1: CLEAN UP TEST DIRECTORIES
# ============================================================================
log "Cleaning up test directories..."
mkdir -p "$OUT_DIR" "$GENERATED_DIR" "$GENERATED_EXPECTED_DIR"
rm -f "$OUT_DIR"/*.o "$OUT_DIR"/"$TEST_BIN_NAME"* "$OUT_DIR"/*.bin "$OUT_DIR"/*.csv
rm -f "$GENERATED_DIR"/*.hex "$GENERATED_EXPECTED_DIR"/*.expected.csv

# ============================================================================
# STEP 2: GENERATE SYNTHETIC TEST DATA
# ============================================================================
USED_SEEDS_FILE="$OUT_DIR/$GENERATED_SEED_FILE_NAME"
> "$USED_SEEDS_FILE"

if [ "$NUM_SYNTHETIC_TESTS" -gt 0 ]; then
  log "Generating $NUM_SYNTHETIC_TESTS synthetic test cases..."
  i=0
  gen_start_time=$(python3 -c "import time; print(time.time())")
  last_update_time="$gen_start_time"
  UPDATE_INTERVAL=2
  
  while [ "$i" -lt "$NUM_SYNTHETIC_TESTS" ]; do
    seed="$RANDOM"
    attempts=0
    while grep -qx "$seed" "$USED_SEEDS_FILE"; do
      seed="$RANDOM"
      attempts=$((attempts + 1))
      if [ "$attempts" -ge "$SEED_RETRY_LIMIT" ]; then
        > "$USED_SEEDS_FILE"
        for hex_file in "$GENERATED_DIR"/"$SYNTHETIC_NAME_PREFIX"*.hex; do
          if [ -f "$hex_file" ]; then
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
    
    python3 "$GENERATOR_SCRIPT_PATH" \
      "$name" "$seed" \
      --hex-dir "$GENERATED_DIR" \
      --expected-dir "$GENERATED_EXPECTED_DIR" > /dev/null 2>&1
    i=$((i + 1))
    
    if [ "$QUIET" -eq 0 ]; then
      read current_time should_update eta <<EOF
$(python3 - <<PY
import time
current = time.time()
should_update = current - $last_update_time >= $UPDATE_INTERVAL or $i >= $NUM_SYNTHETIC_TESTS
if should_update and $i > 0:
    elapsed = current - $gen_start_time
    avg_time = elapsed / $i
    remaining = $NUM_SYNTHETIC_TESTS - $i
    eta_seconds = avg_time * remaining
    if eta_seconds < 60:
        eta = f"{eta_seconds:.0f}s"
    elif eta_seconds < 3600:
        eta = f"{eta_seconds/60:.1f}m"
    else:
        eta = f"{eta_seconds/3600:.1f}h"
    print(f"{current} 1 {eta}")
else:
    print(f"{current} 0")
PY
)
EOF
      
      if [ "$should_update" = "1" ]; then
        printf "\rGenerating synthetic test %d of %d (ETA: %s)...  " "$i" "$NUM_SYNTHETIC_TESTS" "${eta:-}"
        last_update_time="$current_time"
      fi
    fi
  done
  
  if [ "$QUIET" -eq 0 ]; then
    echo ""
  fi
  log "Synthetic test generation complete."
fi

# ============================================================================
# STEP 3: COMPILE ALL OPTIMIZATION LEVELS
# ============================================================================
log "Compiling decoder with all optimization levels..."
clang "${CLANG_INCLUDE_FLAGS[@]}" -Dmain=decoder_main -c "$DECODER_SOURCE_PATH" -o "$OBJ_FILE" 2>/dev/null
clang "${CLANG_INCLUDE_FLAGS[@]}" "$TEST_SOURCE_PATH" "$OBJ_FILE" -o "$TEST_BIN" 2>/dev/null

clang $OPT_FLAG_LIGHT "${CLANG_INCLUDE_FLAGS[@]}" -Dmain=decoder_main -c "$DECODER_SOURCE_PATH" -o "$OBJ_LIGHT_FILE" 2>/dev/null
clang $OPT_FLAG_LIGHT "${CLANG_INCLUDE_FLAGS[@]}" "$TEST_SOURCE_PATH" "$OBJ_LIGHT_FILE" -o "$TEST_BIN_LIGHT" 2>/dev/null

clang $OPT_FLAG_MOD "${CLANG_INCLUDE_FLAGS[@]}" -Dmain=decoder_main -c "$DECODER_SOURCE_PATH" -o "$OBJ_MOD_FILE" 2>/dev/null
clang $OPT_FLAG_MOD "${CLANG_INCLUDE_FLAGS[@]}" "$TEST_SOURCE_PATH" "$OBJ_MOD_FILE" -o "$TEST_BIN_MOD" 2>/dev/null

clang $OPT_FLAG_AGG "${CLANG_INCLUDE_FLAGS[@]}" -Dmain=decoder_main -c "$DECODER_SOURCE_PATH" -o "$OBJ_AGG_FILE" 2>/dev/null
clang $OPT_FLAG_AGG "${CLANG_INCLUDE_FLAGS[@]}" "$TEST_SOURCE_PATH" "$OBJ_AGG_FILE" -o "$TEST_BIN_AGG" 2>/dev/null

log "Compilation complete."

# ============================================================================
# STEP 4: BENCHMARK ALL OPTIMIZATION LEVELS
# ============================================================================
log "Running benchmarks..."

# Convert hex files to binary (do this once, reuse for all optimization levels)
log "Converting hex files to binary..."
for HEX_DIR in "$TEST_DIR" "$GENERATED_DIR"; do
  for HEX_FILE in "$HEX_DIR"/*.hex; do
    if [ ! -e "$HEX_FILE" ]; then
      continue
    fi
    
    base_name=$(basename "$HEX_FILE" .hex)
    BIN_FILE="$OUT_DIR/$base_name.bin"
    
    if command -v xxd >/dev/null 2>&1; then
      xxd -r -p "$HEX_FILE" > "$BIN_FILE"
    else
      python3 "$TEST_DIR/hex_to_bin.py" "$HEX_FILE" "$BIN_FILE"
    fi
  done
done

# Function to run benchmark for a specific optimization level
run_benchmark() {
  opt_level="$1"
  test_bin="$2"
  suffix="$3"
  
  log "Benchmarking $opt_level with $THREADS threads..."
  
  benchmark_start=$(python3 -c "import time; print(time.time())")
  file_count=0
  total_messages=0
  
  # Track throughput on synthetic tests only for consistent workload sizing.
  for HEX_FILE in "$GENERATED_DIR"/*.hex; do
    if [ ! -e "$HEX_FILE" ]; then
      continue
    fi

    base_name=$(basename "$HEX_FILE" .hex)
    BIN_FILE="$OUT_DIR/$base_name.bin"
    OUT_FILE="$OUT_DIR/${base_name}${suffix}.csv"

    file_bytes=$(wc -c < "$BIN_FILE" | tr -d ' ')
    messages_in_file=$((file_bytes / MESSAGE_SIZE_BYTES))
    total_messages=$((total_messages + messages_in_file))

    wait_for_slot
    "$test_bin" "$BIN_FILE" "$OUT_FILE" &
    file_count=$((file_count + 1))
  done
  
  wait_for_all_jobs
  benchmark_end=$(python3 -c "import time; print(time.time())")

  # Keep hardcoded fixture outputs up to date, but exclude them from speed timing.
  for HEX_FILE in "$TEST_DIR"/*.hex; do
    if [ ! -e "$HEX_FILE" ]; then
      continue
    fi

    base_name=$(basename "$HEX_FILE" .hex)
    BIN_FILE="$OUT_DIR/$base_name.bin"
    OUT_FILE="$OUT_DIR/${base_name}${suffix}.csv"

    wait_for_slot
    "$test_bin" "$BIN_FILE" "$OUT_FILE" &
  done
  wait_for_all_jobs
  
  echo "$opt_level|$benchmark_start|$benchmark_end|$file_count|$total_messages"
}

# Run all benchmarks
benchmark_results=""
benchmark_results="$benchmark_results$(run_benchmark 'Unoptimized' "$TEST_BIN" '')
"
benchmark_results="$benchmark_results$(run_benchmark 'Light -O1' "$TEST_BIN_LIGHT" '_light')
"
benchmark_results="$benchmark_results$(run_benchmark 'Moderate -O2' "$TEST_BIN_MOD" '_mod')
"
benchmark_results="$benchmark_results$(run_benchmark 'Aggressive -O3' "$TEST_BIN_AGG" '_agg')
"

# ============================================================================
# STEP 5: COMPARE EXPECTED VS ACTUAL (REPORT FIRST ISSUE ONLY)
# ============================================================================
log "Validating results..."

first_error=""
for HEX_DIR in "$TEST_DIR" "$GENERATED_DIR"; do
  EXPECTED_BASE="$EXPECTED_DIR"
  if [ "$HEX_DIR" = "$GENERATED_DIR" ]; then
    EXPECTED_BASE="$GENERATED_EXPECTED_DIR"
  fi
  
  for HEX_FILE in "$HEX_DIR"/*.hex; do
    if [ ! -e "$HEX_FILE" ]; then
      continue
    fi
    
    base_name=$(basename "$HEX_FILE" .hex)
    EXPECTED_FILE="$EXPECTED_BASE/$base_name.expected.csv"
    
    if [ ! -f "$EXPECTED_FILE" ]; then
      first_error="Missing expected output: $EXPECTED_FILE"
      break 2
    fi
    
    OUT_FILE="$OUT_DIR/$base_name.csv"
    if ! cmp -s "$EXPECTED_FILE" "$OUT_FILE"; then
      first_error="Unoptimized: Output differs from expected for $base_name"
      break 2
    fi
    
    OUT_FILE="$OUT_DIR/${base_name}_light.csv"
    if ! cmp -s "$EXPECTED_FILE" "$OUT_FILE"; then
      first_error="Light -O1: Output differs from expected for $base_name"
      break 2
    fi
    
    OUT_FILE="$OUT_DIR/${base_name}_mod.csv"
    if ! cmp -s "$EXPECTED_FILE" "$OUT_FILE"; then
      first_error="Moderate -O2: Output differs from expected for $base_name"
      break 2
    fi
    
    OUT_FILE="$OUT_DIR/${base_name}_agg.csv"
    if ! cmp -s "$EXPECTED_FILE" "$OUT_FILE"; then
      first_error="Aggressive -O3: Output differs from expected for $base_name"
      break 2
    fi
  done
done

# Report first error if found
if [ -n "$first_error" ]; then
  log_always "ERROR: $first_error"
  
  for HEX_DIR in "$TEST_DIR" "$GENERATED_DIR"; do
    EXPECTED_BASE="$EXPECTED_DIR"
    if [ "$HEX_DIR" = "$GENERATED_DIR" ]; then
      EXPECTED_BASE="$GENERATED_EXPECTED_DIR"
    fi
    
    for HEX_FILE in "$HEX_DIR"/*.hex; do
      if [ ! -e "$HEX_FILE" ]; then
        continue
      fi
      
      base_name=$(basename "$HEX_FILE" .hex)
      EXPECTED_FILE="$EXPECTED_BASE/$base_name.expected.csv"
      
      for suffix in "" "_light" "_mod" "_agg"; do
        OUT_FILE="$OUT_DIR/${base_name}${suffix}.csv"
        if [ -f "$OUT_FILE" ] && [ -f "$EXPECTED_FILE" ]; then
          if ! cmp -s "$EXPECTED_FILE" "$OUT_FILE"; then
            log_always "Red is expected, Green is actual:"
            git diff --no-index -- "$EXPECTED_FILE" "$OUT_FILE" || true
            exit 1
          fi
        fi
      done
    done
  done
  exit 1
fi

log "All tests passed!"

# ============================================================================
# PRINT BENCHMARK RESULTS
# ============================================================================
log_always ""
log_always "Benchmark Results:"
log_always "=================="

echo "$benchmark_results" | grep '|' | while IFS='|' read -r opt_level start_time end_time file_count total_messages; do
  if [ -n "$opt_level" ]; then
  read elapsed msgs_per_sec <<EOF
$(python3 - <<PY
elapsed = $end_time - $start_time
msgs = $total_messages
if elapsed <= 0:
  mps = 0.0
else:
  mps = msgs / elapsed
print(f"{elapsed:.3f} {mps:.1f}")
PY
)
EOF
  log_always "$opt_level: ${elapsed}s for $file_count files, $total_messages messages (${msgs_per_sec} msg/s)"
  fi
done