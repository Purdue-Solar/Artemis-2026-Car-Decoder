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
NUM_SYNTHETIC_TESTS=1000
MESSAGE_COUNT=1000
MESSAGE_SIZE_BYTES=19
SEED_RETRY_LIMIT=100
THREADS=4

TEST_DIR_NAME="Test"
EXPECTED_DIR_NAME="Test_Expected"
GENERATED_DIR_NAME="Test_Generated"
GENERATED_EXPECTED_DIR_NAME="Test_Generated_Expected"
OUT_DIR_NAME="Test_Out"
SCRIPT_DIR_NAME="Test_Scripts"
TARGET_DIR_NAME="target"
BUILD_DIR_NAME="decoder-tests"

GENERATED_SEED_FILE_NAME="generated_seeds.txt"
GENERATOR_SCRIPT_NAME="generate_synthetic_12h.py"
HEX_TO_BIN_SCRIPT_NAME="hex_to_bin.py"
SYNTHETIC_NAME_PREFIX="synthetic_12h_${MESSAGE_COUNT}_"
TEST_SOURCE_NAME="test_decoder.c"

OPT_FLAG_LIGHT="-O1"
OPT_FLAG_MOD="-O2"
OPT_FLAG_AGG="-O3"

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TEST_DIR="$ROOT_DIR/$TEST_DIR_NAME"
EXPECTED_DIR="$ROOT_DIR/$EXPECTED_DIR_NAME"
GENERATED_DIR="$ROOT_DIR/$GENERATED_DIR_NAME"
GENERATED_EXPECTED_DIR="$ROOT_DIR/$GENERATED_EXPECTED_DIR_NAME"
OUT_DIR="$ROOT_DIR/$OUT_DIR_NAME"
SCRIPT_DIR="$ROOT_DIR/$SCRIPT_DIR_NAME"
TARGET_DIR="$ROOT_DIR/$TARGET_DIR_NAME"
BUILD_DIR="$TARGET_DIR/$BUILD_DIR_NAME"
BUILD_BIN_DIR="$BUILD_DIR/bin"
INCLUDE_DIR="$ROOT_DIR/include"
TEST_SOURCE_PATH="$SCRIPT_DIR/$TEST_SOURCE_NAME"
GENERATOR_SCRIPT_PATH="$SCRIPT_DIR/$GENERATOR_SCRIPT_NAME"
HEX_TO_BIN_SCRIPT_PATH="$SCRIPT_DIR/$HEX_TO_BIN_SCRIPT_NAME"

JOBS_FILE="$BUILD_DIR/discovered_jobs.tsv"
BIN_MAP_FILE="$BUILD_DIR/job_bins.tsv"
HARDCODED_NAMES_FILE="$BUILD_DIR/hardcoded_hex_names.txt"
SYNTH_NAMES_FILE="$BUILD_DIR/synthetic_hex_names.txt"
BENCHMARK_RESULTS_FILE="$BUILD_DIR/benchmark_results.tsv"
WARN_ONCE_FILE="$BUILD_DIR/warn_once.tsv"

# ============================================================================
# MAIN EXECUTION
# ============================================================================

MAIN_WORKFLOW=$(cat <<'EOF'
validate_required_inputs
prepare_output_dirs

log "Cleaning up test directories..."
cleanup_previous_outputs

log "Discovering job definitions from YAML..."
discover_jobs_from_yaml "$ROOT_DIR" "$JOBS_FILE"
require_non_empty_file "$JOBS_FILE" "No valid jobs discovered. Add at least one YAML file with jobs."
log "Discovered $(wc -l < "$JOBS_FILE" | tr -d ' ') job(s)."

log "Compiling all jobs with all optimization levels..."
compile_all_jobs
log "Compilation complete."

log "Converting hardcoded test hex files to binary..."
convert_hex_directory "$TEST_DIR"
collect_hex_basenames "$TEST_DIR" "$HARDCODED_NAMES_FILE"

log "Running hardcoded tests for all jobs..."
run_tests_for_name_list "$HARDCODED_NAMES_FILE"

log "Validating hardcoded test outputs..."
validate_outputs_for_name_list "$HARDCODED_NAMES_FILE" "$EXPECTED_DIR" "hardcoded"

if [ "$NUM_SYNTHETIC_TESTS" -gt 0 ]; then
  log "Generating $NUM_SYNTHETIC_TESTS synthetic test cases..."
  generate_synthetic_tests
  log "Synthetic test generation complete."

  log "Converting synthetic test hex files to binary..."
  convert_hex_directory "$GENERATED_DIR"
  collect_hex_basenames "$GENERATED_DIR" "$SYNTH_NAMES_FILE"

  log "Running synthetic tests for all jobs..."
  run_tests_for_name_list "$SYNTH_NAMES_FILE"

  log "Validating synthetic outputs..."
  validate_outputs_for_name_list "$SYNTH_NAMES_FILE" "$GENERATED_EXPECTED_DIR" "synthetic"

  log "Running benchmarks..."
  benchmark_all_jobs "$SYNTH_NAMES_FILE"
  print_benchmark_results
fi

log "All tests passed!"
EOF
)


# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
  if [ "$QUIET" -eq 0 ]; then
    echo "$@"
  fi
}

log_always() {
  echo "$@"
}

warn_once() {
  warn_key="$1"
  shift
  warn_message="$*"

  mkdir -p "$BUILD_DIR"
  touch "$WARN_ONCE_FILE"
  if ! grep -Fxq "$warn_key" "$WARN_ONCE_FILE"; then
    printf '%s\n' "$warn_key" >> "$WARN_ONCE_FILE"
    log "$warn_message"
  fi
}

wait_for_slot() {
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$THREADS" ]; do
    sleep 0.05
  done
}

wait_for_all_jobs() {
  wait
}

require_non_empty_file() {
  file_path="$1"
  message="$2"
  if [ ! -s "$file_path" ]; then
    log_always "ERROR: $message"
    exit 1
  fi
}

validate_required_inputs() {
  if [ ! -d "$TEST_DIR" ]; then
    log_always "ERROR: Test directory not found at $TEST_DIR"
    exit 1
  fi
  if [ ! -d "$EXPECTED_DIR" ]; then
    log_always "ERROR: Expected directory not found at $EXPECTED_DIR"
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
  if [ ! -f "$HEX_TO_BIN_SCRIPT_PATH" ]; then
    log_always "ERROR: Hex to bin script not found at $HEX_TO_BIN_SCRIPT_PATH"
    exit 1
  fi
}

prepare_output_dirs() {
  mkdir -p "$OUT_DIR" "$GENERATED_DIR" "$GENERATED_EXPECTED_DIR" "$BUILD_BIN_DIR"
}

cleanup_previous_outputs() {
  rm -f "$OUT_DIR"/*.bin
  rm -f "$OUT_DIR"/*.csv
  rm -f "$BUILD_DIR"/*.tsv
  rm -f "$BUILD_DIR"/*.txt
  rm -rf "$BUILD_BIN_DIR"
  mkdir -p "$BUILD_BIN_DIR"
  rm -f "$GENERATED_DIR"/*.hex
  rm -f "$GENERATED_EXPECTED_DIR"/*.expected.csv
}

discover_jobs_from_yaml() {
  search_root="$1"
  output_file="$2"

  python3 - "$search_root" > "$output_file" <<'PY'
import os
import re
import sys

root = os.path.abspath(sys.argv[1])

def warn(msg):
    sys.stderr.write("WARN: " + msg + "\n")

def parse_minimal_yaml(text):
    jobs = {}
    in_jobs = False
    current_job = None
    current_key = None
    for raw_line in text.splitlines():
        line = raw_line.split('#', 1)[0].rstrip()
        if not line.strip():
            continue
        if not in_jobs:
            if re.match(r'^jobs\s*:\s*$', line):
                in_jobs = True
            continue
        if re.match(r'^\S', line):
            break

        m_job = re.match(r'^\s{2}([A-Za-z0-9_.:-]+)\s*:\s*$', line)
        if m_job:
            current_job = m_job.group(1)
            jobs[current_job] = {}
            current_key = None
            continue

        m_key = re.match(r'^\s{4}(c_files|files|sources)\s*:\s*(.*)$', line)
        if m_key and current_job is not None:
            key = m_key.group(1)
            value = m_key.group(2).strip()
            current_key = key
            if not value:
                jobs[current_job][key] = []
            else:
                if value.startswith('[') and value.endswith(']'):
                    inside = value[1:-1].strip()
                    items = [x.strip().strip('"\'') for x in inside.split(',') if x.strip()]
                    jobs[current_job][key] = items
                else:
                    jobs[current_job][key] = value.strip('"\'')
            continue

        m_item = re.match(r'^\s{6}-\s*(.+)$', line)
        if m_item and current_job is not None and current_key is not None:
            item = m_item.group(1).strip().strip('"\'')
            existing = jobs[current_job].get(current_key)
            if isinstance(existing, list):
                existing.append(item)
            elif existing is None:
                jobs[current_job][current_key] = [item]
            else:
                jobs[current_job][current_key] = [str(existing), item]
    return {"jobs": jobs}

def extract_jobs(data):
    if not isinstance(data, dict):
        return []
    jobs = data.get("jobs")
    out = []
    if isinstance(jobs, dict):
        for job_name, cfg in jobs.items():
            out.append((str(job_name), cfg))
    elif isinstance(jobs, list):
        idx = 0
        for item in jobs:
            idx += 1
            if isinstance(item, dict):
                job_name = item.get("name")
                if not job_name:
                    job_name = f"job_{idx}"
                out.append((str(job_name), item))
    return out

def extract_c_files(cfg):
    if isinstance(cfg, dict):
        for key in ("c_files", "files", "sources", "cFiles"):
            if key in cfg:
                value = cfg[key]
                break
        else:
            return []
    elif isinstance(cfg, list):
        value = cfg
    elif isinstance(cfg, str):
        value = cfg
    else:
        return []

    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        files = []
        for v in value:
            if isinstance(v, str):
                files.append(v)
        return files
    return []

def normalize_job_files(job_dir, requested):
  dir_source_files = sorted(
    [
      name
      for name in os.listdir(job_dir)
      if (name.endswith('.c') or name.endswith('.h')) and os.path.isfile(os.path.join(job_dir, name))
    ]
  )
  if not requested:
    return []

  expanded = []
  for item in requested:
    token = item.strip()
    if token.lower() == "all":
      expanded.extend(dir_source_files)
    else:
      expanded.append(token)

  result = []
  seen = set()
  for item in expanded:
    path = os.path.join(job_dir, item)
    if os.path.isfile(path) and (item.endswith('.c') or item.endswith('.h')):
      if item not in seen:
        seen.add(item)
        result.append(item)
    else:
      warn(f"Skipping missing/non-source file '{item}' in {job_dir}")
  return result

def parse_yaml_file(path):
    text = open(path, "r", encoding="utf-8").read()
    try:
        import yaml  # type: ignore
        return yaml.safe_load(text)
    except Exception:
        return parse_minimal_yaml(text)

records = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d != ".git"]
    for name in filenames:
        if not name.endswith('.yaml'):
            continue
        yaml_path = os.path.join(dirpath, name)
        try:
            data = parse_yaml_file(yaml_path)
        except Exception as ex:
            warn(f"Failed to parse {yaml_path}: {ex}")
            continue

        jobs = extract_jobs(data)
        if not jobs:
            continue

        dir_name = os.path.basename(dirpath.rstrip(os.sep)) or "."
        for job_name, cfg in jobs:
            requested_files = extract_c_files(cfg)
            c_files = normalize_job_files(dirpath, requested_files)
            if not c_files:
                warn(f"Skipping empty job '{job_name}' in {yaml_path}")
                continue
            job_id = f"{dir_name}:{job_name}"
            records.append((job_id, dirpath, dir_name, job_name, ",".join(c_files)))

records.sort(key=lambda r: (r[2], r[3]))
for rec in records:
    print("\t".join(rec))
PY
}

sanitize_name() {
  echo "$1" | tr -c 'A-Za-z0-9_.-' '_'
}

compile_all_jobs() {
  : > "$BIN_MAP_FILE"

  while IFS=$'\t' read -r job_id job_dir dir_name job_name source_csv; do
    [ -n "$job_id" ] || continue
    job_safe=$(sanitize_name "$job_id")
    dir_safe=$(sanitize_name "$dir_name")
    name_safe=$(sanitize_name "$job_name")

    compile_job_variant "$job_id" "$job_dir" "$source_csv" "" "" "Unoptimized" "$job_safe" "$dir_safe" "$name_safe"
    compile_job_variant "$job_id" "$job_dir" "$source_csv" "$OPT_FLAG_LIGHT" "_light" "Light -O1" "$job_safe" "$dir_safe" "$name_safe"
    compile_job_variant "$job_id" "$job_dir" "$source_csv" "$OPT_FLAG_MOD" "_mod" "Moderate -O2" "$job_safe" "$dir_safe" "$name_safe"
    compile_job_variant "$job_id" "$job_dir" "$source_csv" "$OPT_FLAG_AGG" "_agg" "Aggressive -O3" "$job_safe" "$dir_safe" "$name_safe"
  done < "$JOBS_FILE"
}

compile_job_variant() {
  job_id="$1"
  job_dir="$2"
  source_csv="$3"
  opt_flag="$4"
  suffix="$5"
  variant_label="$6"
  job_safe="$7"
  dir_safe="$8"
  name_safe="$9"

  include_flags=(-I"$ROOT_DIR" -I"$job_dir" -I"$INCLUDE_DIR")
  if [ -n "$opt_flag" ]; then
    compile_flags=("$opt_flag" "${include_flags[@]}")
  else
    compile_flags=("${include_flags[@]}")
  fi

  job_bin_dir="$BUILD_BIN_DIR/$dir_safe/$name_safe"
  mkdir -p "$job_bin_dir"

  compile_inputs=()
  old_ifs="$IFS"
  IFS=','
  c_source_count=0
  for src_file in $source_csv; do
    case "$src_file" in
      *.h)
        # Headers are valid job members, but they are not standalone compile units.
        continue
        ;;
      *.c)
        c_source_count=$((c_source_count + 1))
        ;;
      *)
        log_always "ERROR: $job_id: Unsupported source extension in $src_file"
        exit 1
        ;;
    esac

    src_path="$job_dir/$src_file"
    if [ ! -f "$src_path" ]; then
      log_always "ERROR: $job_id: Missing source file $src_path"
      exit 1
    fi
    compile_inputs+=("$src_path")
  done
  IFS="$old_ifs"

  if [ "$c_source_count" -eq 0 ]; then
    log_always "ERROR: $job_id: Job does not include any .c compile units"
    exit 1
  fi

  bin_path="$job_bin_dir/job_bin_${job_safe}${suffix}"

  # Fallback build should use library-like sources only, since test_decoder.c
  # provides the main() entry point.
  fallback_inputs=()
  for src_path in "${compile_inputs[@]}"; do
    if grep -Eq '^[[:space:]]*int[[:space:]]+main[[:space:]]*\(' "$src_path"; then
      continue
    fi
    fallback_inputs+=("$src_path")
  done

  # Try standalone build first. If that fails (for example, no main entry point),
  # retry with the test harness as a fallback.
  standalone_log="$job_bin_dir/job_bin_${job_safe}${suffix}.standalone.log"
  fallback_log="$job_bin_dir/job_bin_${job_safe}${suffix}.fallback.log"
  probe_input="$job_bin_dir/job_bin_${job_safe}${suffix}.probe_input.bin"
  probe_output="$job_bin_dir/job_bin_${job_safe}${suffix}.probe_output.csv"

  if clang "${compile_flags[@]}" "${compile_inputs[@]}" -o "$bin_path" 2>"$standalone_log"; then
    # Probe the runtime argument contract expected by the test runner:
    # executable with no args, reading stdin and writing stdout
    : > "$probe_input"
    if "$bin_path" < "$probe_input" > "$probe_output" 2>/dev/null; then
      rm -f "$standalone_log" "$fallback_log" "$probe_input" "$probe_output"
    else
      if [ ! -f "$TEST_SOURCE_PATH" ]; then
        log_always "ERROR: $job_id: Standalone runtime contract probe failed and test harness is missing at $TEST_SOURCE_PATH"
        log_always "Standalone compiler output:"
        cat "$standalone_log"
        exit 1
      fi

      warn_once "$job_id|arg_contract_mismatch" "WARN: $job_id: Standalone binary argument contract mismatch, retrying with test harness fallback"
      if clang "${compile_flags[@]}" "${fallback_inputs[@]}" "$TEST_SOURCE_PATH" -o "$bin_path" 2>"$fallback_log"; then
        rm -f "$standalone_log" "$fallback_log" "$probe_input" "$probe_output"
      else
        log_always "ERROR: $job_id: Standalone compile succeeded but runtime contract probe failed, and fallback compilation also failed"
        log_always "Standalone compiler output:"
        cat "$standalone_log"
        log_always "Fallback compiler output:"
        cat "$fallback_log"
        exit 1
      fi
    fi
  else
    if [ ! -f "$TEST_SOURCE_PATH" ]; then
      log_always "ERROR: $job_id: Standalone compilation failed and test harness is missing at $TEST_SOURCE_PATH"
      log_always "Standalone compiler output:"
      cat "$standalone_log"
      exit 1
    fi

    warn_once "$job_id|standalone_compile_failed" "WARN: $job_id: Standalone compile failed, retrying with test harness fallback"
    if clang "${compile_flags[@]}" "${fallback_inputs[@]}" "$TEST_SOURCE_PATH" -o "$bin_path" 2>"$fallback_log"; then
      rm -f "$standalone_log" "$fallback_log" "$probe_input" "$probe_output"
    else
      log_always "ERROR: $job_id: Compilation failed for both standalone and test harness fallback"
      log_always "Standalone compiler output:"
      cat "$standalone_log"
      log_always "Fallback compiler output:"
      cat "$fallback_log"
      exit 1
    fi
  fi

  printf '%s|%s|%s|%s|%s\n' "$job_id" "$job_safe" "$variant_label" "$suffix" "$bin_path" >> "$BIN_MAP_FILE"
}

convert_hex_directory() {
  hex_dir="$1"
  for hex_file in "$hex_dir"/*.hex; do
    if [ ! -e "$hex_file" ]; then
      continue
    fi
    base_name=$(basename "$hex_file" .hex)
    bin_file="$OUT_DIR/$base_name.bin"
    if command -v xxd >/dev/null 2>&1; then
      xxd -r -p "$hex_file" > "$bin_file"
    else
      python3 "$HEX_TO_BIN_SCRIPT_PATH" "$hex_file" "$bin_file"
    fi
  done
}

collect_hex_basenames() {
  hex_dir="$1"
  out_file="$2"
  : > "$out_file"
  for hex_file in "$hex_dir"/*.hex; do
    if [ ! -e "$hex_file" ]; then
      continue
    fi
    basename "$hex_file" .hex >> "$out_file"
  done
}

run_tests_for_name_list() {
  names_file="$1"
  while IFS='|' read -r job_id job_safe variant_label suffix bin_path; do
    [ -n "$job_id" ] || continue
    while IFS= read -r base_name; do
      [ -n "$base_name" ] || continue
      bin_input="$OUT_DIR/$base_name.bin"
      out_file="$OUT_DIR/${job_safe}_${base_name}${suffix}.csv"
      wait_for_slot
      "$bin_path" < "$bin_input" > "$out_file" &
    done < "$names_file"
    wait_for_all_jobs
  done < "$BIN_MAP_FILE"
}

validate_outputs_for_name_list() {
  names_file="$1"
  expected_base_dir="$2"
  phase_label="$3"

  while IFS='|' read -r job_id job_safe variant_label suffix bin_path; do
    [ -n "$job_id" ] || continue
    while IFS= read -r base_name; do
      [ -n "$base_name" ] || continue
      expected_file="$expected_base_dir/$base_name.expected.csv"
      out_file="$OUT_DIR/${job_safe}_${base_name}${suffix}.csv"

      if [ ! -f "$expected_file" ]; then
        log_always "ERROR: $job_id: Missing expected output for $phase_label test: $expected_file"
        exit 1
      fi
      if [ ! -f "$out_file" ]; then
        log_always "ERROR: $job_id: Missing produced output for $phase_label test: $out_file"
        exit 1
      fi

      if ! cmp -s "$expected_file" "$out_file"; then
        log_always "ERROR: $job_id: $variant_label: Output differs from expected for $base_name"
        log_always "Red is expected, Green is actual:"
        git diff --no-index -- "$expected_file" "$out_file" || true
        exit 1
      fi
    done < "$names_file"
  done < "$BIN_MAP_FILE"
}

generate_synthetic_tests() {
  used_seeds_file="$OUT_DIR/$GENERATED_SEED_FILE_NAME"
  : > "$used_seeds_file"

  i=0
  gen_start_time=$(python3 -c "import time; print(time.time())")
  last_update_time="$gen_start_time"
  update_interval=2

  while [ "$i" -lt "$NUM_SYNTHETIC_TESTS" ]; do
    seed="$RANDOM"
    attempts=0

    while grep -qx "$seed" "$used_seeds_file"; do
      seed="$RANDOM"
      attempts=$((attempts + 1))
      if [ "$attempts" -ge "$SEED_RETRY_LIMIT" ]; then
        : > "$used_seeds_file"
        for hex_file in "$GENERATED_DIR"/"$SYNTHETIC_NAME_PREFIX"*.hex; do
          if [ -f "$hex_file" ]; then
            basename_only=$(basename "$hex_file" .hex)
            extracted_seed="${basename_only#$SYNTHETIC_NAME_PREFIX}"
            echo "$extracted_seed" >> "$used_seeds_file"
          fi
        done
        attempts=0
      fi
    done

    echo "$seed" >> "$used_seeds_file"
    name="$SYNTHETIC_NAME_PREFIX$seed"

    python3 "$GENERATOR_SCRIPT_PATH" \
      "$name" "$seed" \
      --message-count "$MESSAGE_COUNT" \
      --hex-dir "$GENERATED_DIR" \
      --expected-dir "$GENERATED_EXPECTED_DIR" > /dev/null 2>&1

    i=$((i + 1))

    if [ "$QUIET" -eq 0 ]; then
      read current_time should_update eta <<EOF
$(python3 - <<PY
import time
current = time.time()
should_update = current - $last_update_time >= $update_interval or $i >= $NUM_SYNTHETIC_TESTS
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
}

benchmark_all_jobs() {
  names_file="$1"
  : > "$BENCHMARK_RESULTS_FILE"

  while IFS='|' read -r job_id job_safe variant_label suffix bin_path; do
    [ -n "$job_id" ] || continue

    benchmark_start=$(python3 -c "import time; print(time.time())")
    file_count=0
    total_messages=0

    while IFS= read -r base_name; do
      [ -n "$base_name" ] || continue
      bin_input="$OUT_DIR/$base_name.bin"
      out_file="$OUT_DIR/${job_safe}_${base_name}${suffix}.csv"

      file_bytes=$(wc -c < "$bin_input" | tr -d ' ')
      messages_in_file=$((file_bytes / MESSAGE_SIZE_BYTES))
      total_messages=$((total_messages + messages_in_file))

      wait_for_slot
      "$bin_path" < "$bin_input" > "$out_file" &
      file_count=$((file_count + 1))
    done < "$names_file"
    wait_for_all_jobs

    benchmark_end=$(python3 -c "import time; print(time.time())")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$job_id" "$variant_label" "$benchmark_start" "$benchmark_end" "$file_count" "$total_messages" >> "$BENCHMARK_RESULTS_FILE"
  done < "$BIN_MAP_FILE"
}

print_benchmark_results() {
  current_job=""
  log_always ""
  while IFS=$'\t' read -r job_id variant_label start_time end_time file_count total_messages; do
    [ -n "$job_id" ] || continue
    if [ "$job_id" != "$current_job" ]; then
      current_job="$job_id"
      log_always "$job_id"
      log_always "Benchmark Results:"
      log_always "=================="
    fi

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
    log_always "$variant_label: ${elapsed}s for $file_count files, $total_messages messages (${msgs_per_sec} msg/s)"
  done < "$BENCHMARK_RESULTS_FILE"
}

eval "$MAIN_WORKFLOW"
