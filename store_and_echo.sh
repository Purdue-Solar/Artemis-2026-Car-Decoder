#!/bin/bash
cd "$(dirname "$0")"

if [ ! -f "./store_output.txt" ]; then
    echo "Missing store_output.txt file."
    exit 1
fi

output_file="$1"

while IFS= read -r line; do
    echo "$line"
    echo "$line" >> "$output_file"
done