#!/bin/bash

# this part is suggested by Chatgpt, I dont know the detail
# set -euo pipefail
# IFS=$'\n\t'

# Create output directory
output_dir="processed"
output_format="opus"

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

# wrap the entire flow in a big while and if clause
while IFS= read -r name; do
    meta_json="${name}.info.json"
    source_file="${name}.${output_format}"

    if ! jq empty "$meta_json" 2>/dev/null; then
        echo "Warning: Invalid JSON in $meta_json. Skipping..."
        continue
    elif [[ ! -f "$source_file" ]]; then
        echo "Warning: Missing audio file for '$name'. Skipping..."
        continue
    elif jq 'has("chapters") and (.chapters != null and (.chapters | length > 0))' "$meta_json" | grep -q true; then
        echo "✅ JSON file has non-empty chapters, processing chapters for ${source_file}"

        total_tracks=$(jq '.chapters | length' "$meta_json")
        for ((i = 0; i < total_tracks; i++)); do
            chapter_start=$(jq -r --argjson i "$i" '.chapters[$i].start_time | floor' "$meta_json")
            chapter_end=$(jq -r --argjson i "$i" '.chapters[$i].end_time | floor' "$meta_json")
            chapter_album=$(jq -r '.title // "Unknown Album"' "$meta_json")
            chapter_artist=$(jq -r '.uploader // "Unknown Artist"' "$meta_json")
            chapter_title=$(jq -r --argjson i "$i" '.chapters[$i].title // "Unknown Title"' "$meta_json")
            chapter_track_number=$((i + 1))

            safe_album=$(sanitize_metadata "$chapter_album")
            safe_title=$(sanitize_metadata "$chapter_title")
            chapter_song_target_dir="./${output_dir}/${safe_album}"
            chapter_song_target_file="$chapter_song_target_dir/${safe_title}.${output_format}"

            if [[ ! -d "$chapter_song_target_dir" ]]; then
                echo "Directory does not exist. Creating: $chapter_song_target_dir"
                mkdir -p "$chapter_song_target_dir"
            fi

            if [[ -f "$chapter_song_target_file" ]]; then
                echo "Skipping '$chapter_title' — already exists."
                continue
            else
                echo "Processing: $chapter_song_target_file"
                ffmpeg -y -ss "$chapter_start" -i "$source_file" -to "$chapter_end" -c copy \
                    -id3v2_version 3 \
                    -metadata title="$chapter_title" \
                    -metadata album="$chapter_album" \
                    -metadata artist="$chapter_artist" \
                    -metadata track="$chapter_track_number" \
                    -loglevel 0 \
                    -nostats \
                    "$chapter_song_target_file"
            fi
            echo "Processing complete! Check new files in '$chapter_song_target_file'."

        done
    else
        album=$(jq -r '.playlist_title // "Unknown Album"' "$meta_json")
        artist=$(jq -r '.artists[0] // "Unknown Artist"' "$meta_json")
        track_number=$(jq -r '.playlist_index // 0' "$meta_json")
        title=$(jq -r '.title // "Unknown Title"' "$meta_json")

        safe_album=$(sanitize_metadata "$album")
        safe_name=$(sanitize_metadata "$name")
        target_dir="./${output_dir}/${safe_album}"
        target_file="$target_dir/${safe_name}.${output_format}"

        if [[ ! -d "$target_dir" ]]; then
            echo "Directory does not exist. Creating: $target_dir"
            mkdir -p "$target_dir"
        fi

        if [[ -f "$target_file" ]]; then
            echo "Skipping '$target_file' — already exists."
            continue
        else
            echo "Processing: $target_file"
            ffmpeg -y -i "$source_file" -loglevel 0 \
                -nostats \
                -c copy \
                -id3v2_version 3 \
                -hide_banner \
                -metadata title="$title" \
                -metadata album="$album" \
                -metadata artist="$artist" \
                -metadata track="$track_number" \
                "$target_file"
        fi
        echo "Processing complete! Check new files in '$target_file'."

    fi

done < <(find . -type f -name "*.info.json" -exec basename {} .info.json \;)
