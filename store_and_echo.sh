#!/bin/bash
cd "$(dirname "$0")"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_file_path>"
    exit 1
fi

output_file="$1"

while IFS= read -r line; do
    echo "$line"
    echo "$line" >> "$output_file"
done