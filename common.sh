#!/bin/bash

# Get the list of files in the current directory
files=(ls -A1)

# Get the first filename as the initial prefix
common="${files[0]}"

# Loop through all files and shorten the common prefix
for file in "${files[@]}"; do
  while [[ "${file:0:${#common}}" != "$common" ]]; do
    common="${common:0:$((${#common}-1))}"
  done
done

# Trim leading './' if desired
common="${common#./}"

# Print the common part
echo "Common prefix: $common"
