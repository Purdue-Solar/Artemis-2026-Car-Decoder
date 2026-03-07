#!/usr/bin/env python3
"""Compare optimization levels: -O0 (unoptimized), -O1 (light), -O2 (moderate), -O3 (aggressive)."""
import sys

unopt_start = float(sys.argv[1])
unopt_end = float(sys.argv[2])
light_start = float(sys.argv[3])
light_end = float(sys.argv[4])
mod_start = float(sys.argv[5])
mod_end = float(sys.argv[6])
agg_start = float(sys.argv[7])
agg_end = float(sys.argv[8])
count = int(sys.argv[9])
message_count = int(sys.argv[10])

unopt_elapsed = unopt_end - unopt_start
light_elapsed = light_end - light_start
mod_elapsed = mod_end - mod_start
agg_elapsed = agg_end - agg_start

unopt_tests_per_sec = count / unopt_elapsed if unopt_elapsed > 0 else 0.0
light_tests_per_sec = count / light_elapsed if light_elapsed > 0 else 0.0
mod_tests_per_sec = count / mod_elapsed if mod_elapsed > 0 else 0.0
agg_tests_per_sec = count / agg_elapsed if agg_elapsed > 0 else 0.0
unopt_msgs_per_sec = (
    (count * message_count) / unopt_elapsed if unopt_elapsed > 0 else 0.0
)
light_msgs_per_sec = (
    (count * message_count) / light_elapsed if light_elapsed > 0 else 0.0
)
mod_msgs_per_sec = (count * message_count) / mod_elapsed if mod_elapsed > 0 else 0.0
agg_msgs_per_sec = (count * message_count) / agg_elapsed if agg_elapsed > 0 else 0.0

print("")
print("Optimization Benchmark (Generated Suite):")
print(f"  Tests:   {count}")
print(f"")
print(f"  Unoptimized (-O0):")
print(f"    Total:           {unopt_elapsed:.3f}s")
print(f"    Tests/sec:       {unopt_tests_per_sec:.3f}")
print(f"    Msgs/sec:        {unopt_msgs_per_sec:.3f}")
print(f"")
print(f"  Light Optimization (-O1):")
print(f"    Total:           {light_elapsed:.3f}s")
print(f"    Tests/sec:       {light_tests_per_sec:.3f}")
print(f"    Msgs/sec:        {light_msgs_per_sec:.3f}")
print(f"")
print(f"  Moderate Optimization (-O2):")
print(f"    Total:           {mod_elapsed:.3f}s")
print(f"    Tests/sec:       {mod_tests_per_sec:.3f}")
print(f"    Msgs/sec:        {mod_msgs_per_sec:.3f}")
print(f"")
print(f"  Aggressive Optimization (-O3):")
print(f"    Total:           {agg_elapsed:.3f}s")
print(f"    Tests/sec:       {agg_tests_per_sec:.3f}")
print(f"    Msgs/sec:        {agg_msgs_per_sec:.3f}")
