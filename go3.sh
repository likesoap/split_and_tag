#!/bin/bash

# Create output directory
output_dir="./processed/"

required_cmds=("jq" "ffmpeg")

for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed." >&2
        exit 1
    fi
done

# Quote the variable to preserve line breaks (handles filenames with spaces)
while IFS= read -r name; do
    extracted_file_json="${name}.info.json"
    extracted_file="${name}.opus"
    outfileName="${extracted_file}"

    # Check if the associated .opus file exists
    if [[ ! -f "$extracted_file" ]]; then
        echo "Warning: Missing audio file for '$name'. Skipping..."
        continue
    fi

    # Read JSON file content using jq safely
    album=$(jq -r '.playlist_title // "Unknown Album"' "$extracted_file_json")
    artist=$(jq -r '.artists[0] // "Unknown Artist"' "$extracted_file_json")
    track_number=$(jq -r '.playlist_index // 0' "$extracted_file_json")
    title=$(jq -r '.title // "Unknown Title"' "$extracted_file_json")

    target_dir="./${output_dir}/${album}"

    # Check if the directory exists
    if [ ! -d "$target_dir" ]; then
        echo "Directory does not exist. Creating: $target_dir"
        mkdir -p "$target_dir"
    else
        echo "Directory already exists: $target_dir"
    fi

    # Process audio with ffmpeg
    ffmpeg -y -i "$extracted_file" -c copy \
        -id3v2_version 3 \
        -hide_banner \
        -metadata title="$title" \
        -metadata album="$album" \
        -metadata artist="$artist" \
        -metadata track="$track_number" \
        -loglevel error \
        "$target_dir/$outfileName"

done < <(find . -type f -name "*.info.json" -exec basename {} .info.json \;)

echo "Processing complete! Files saved in '$output_dir' directory."
