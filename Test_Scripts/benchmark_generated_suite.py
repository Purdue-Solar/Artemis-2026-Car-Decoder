#!/usr/bin/env python3
"""Benchmark generated test suite performance."""
import sys

start = float(sys.argv[1])
end = float(sys.argv[2])
count = int(sys.argv[3])
message_count = int(sys.argv[4])

elapsed = end - start
tests_per_sec = count / elapsed if elapsed > 0 else 0.0
msgs_per_sec = (count * message_count) / elapsed if elapsed > 0 else 0.0

print("Generated suite benchmark:")
print(f"  Tests:   {count}")
print(f"  Total:   {elapsed:.3f}s")
print(f"  Avg tests/sec:   {tests_per_sec:.3f}")
print(f"  Avg msgs/sec:    {msgs_per_sec:.3f}")
