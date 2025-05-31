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

    if jq 'has("chapters") and (.chapters != null and (.chapters | length > 0))' "$meta_json" | grep -q true; then
        echo "✅ JSON file has non-empty chapters, processing chapters for ${source_file}"
        # loop through chapter id:
        total_tracks=$(jq '.chapters | length' "$meta_json")
        for ((i = 0; i < $total_tracks; i++)); do
            chapter_start=$(jq -r --argjson i "$i" '.chapters[$i].start_time | floor' "$meta_json")
            chapter_end=$(jq -r --argjson i "$i" '.chapters[$i].end_time | floor' "$meta_json")
            chapter_album=$(jq -r '.title // "Unknown Album"' "$meta_json")
            chapter_artist=$(jq -r '.uploader // "Unknown Artist"' "$meta_json")
            chapter_title=$(jq -r --argjson i "$i" '.chapters[$i].title // "Unknown Title"' "$meta_json")
            chapter_track_number=$((i + 1))
            chapter_song_target_dir="./${output_dir}/$chapter_album)"
            chapter_song_target_file="$chapter_song_target_dir/${chapter_title}.opus"

            if [ ! -d "$chapter_song_target_dir" ]; then
                echo "Directory does not exist. Creating: $chapter_song_target_dir"
                mkdir -p "$chapter_song_target_dir"

            fi

            # Skip if output file already exists
            if [[ -f "$chapter_song_target_file" ]]; then
                echo "Skipping '$chapter_title' — already exists."
                continue
            fi

            ffmpeg -y -ss "$chapter_start" -i "$source_file" -to "$chapter_end" -c copy \
                -id3v2_version 3 \
                -metadata title="$chapter_title" \
                -metadata album="$chapter_album" \
                -metadata artist="$chapter_artist" \
                -metadata track="$chapter_track_number" \
                "$chapter_song_target_file"

        done

    else
        # prepare meta data
        album=$(jq -r '.playlist_title // "Unknown Album"' "$meta_json")
        artist=$(jq -r '.artists[0] // "Unknown Artist"' "$meta_json")
        track_number=$(jq -r '.playlist_index // 0' "$meta_json")
        title=$(jq -r '.title // "Unknown Title"' "$meta_json")

        #define output path and filenames, removing the non regonizable characters
        target_dir="./${output_dir}/${album}"
        target_file="$target_dir/${name}.opus"

        # check if target dir exists
        if [ ! -d "$target_dir" ]; then
            echo "Directory does not exist. Creating: $target_dir"
            mkdir -p "$target_dir"
        fi

        # Skip if output file already exists
        if [[ -f "$target_file" ]]; then
            echo "Skipping '$outfileName' — already exists."
            continue
        fi

        ffmpeg -y -i "$source_file" -c copy \
            -id3v2_version 3 \
            -hide_banner \
            -metadata title="$title" \
            -metadata album="$album" \
            -metadata artist="$artist" \
            -metadata track="$track_number" \
            -loglevel error \
            "$target_file"

    fi

done \
    < <(find . -type f -name "*.info.json" -exec basename {} .info.json \;)

echo "Processing complete! Files saved in '$output_dir' directory."
