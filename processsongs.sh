#!/bin/bash

# Create output directory
output_dir="processed"

# fix error parts in file names
sanitize_metadata() {
    echo "$1" | iconv -c -f UTF-8 -t ASCII//TRANSLIT | tr -cd '[:alnum:]._ -'
}

#check if all dependencies are good
required_cmds=("jq" "ffmpeg")
for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed." >&2
        exit 1
    fi
done

# process the source files
while IFS= read -r name; do
    meta_json="${name}.info.json"
    source_file="${name}.opus"

    # Check if the associated .opus file exists
    if [[ ! -f "$source_file" ]]; then
        echo "Warning: Missing audio file for '$name'. Skipping..."
        continue
    fi

    # prepare meta data
    album=$(jq -r '.playlist_title // "Unknown Album"' "$meta_json")
    artist=$(jq -r '.artists[0] // "Unknown Artist"' "$meta_json")
    track_number=$(jq -r '.playlist_index // 0' "$meta_json")
    title=$(jq -r '.title // "Unknown Title"' "$meta_json")

    #define output path and filenames, removing the non regonizable characters
    target_dir="./${output_dir}/$(sanitize_metadata "$album")"
    target_file="$target_dir/$(sanitize_metadata "$name").opus"

    # check if target dir exists
    if [ ! -d "$target_dir" ]; then
        echo "Directory does not exist. Creating: $target_dir"
        mkdir -p "$target_dir"

    # Skip if output file already exists
    elif [[ ! -f "$target_file" ]]; then
        ffmpeg -y -i "$source_file" -c copy \
            -id3v2_version 3 \
            -hide_banner \
            -metadata title="$title" \
            -metadata album="$album" \
            -metadata artist="$artist" \
            -metadata track="$track_number" \
            -loglevel error \
            "$target_file"
    else
        echo "Skipping '$outfileName' — already exists."
        continue
    fi

done < <(find . -type f -name "*.info.json" -exec basename {} .info.json \;)

echo "Processing complete! Files saved in '$output_dir' directory."
