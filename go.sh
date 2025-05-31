#!/bin/bash

# Check if URL is provided
if [ -z "$1" ]; then
    echo "Usage: ./go.sh <URL>"
    exit 1
fi

url="$1"

# Define yt-dlp command with configurations
ytdlp_output=$(yt-dlp \
    --ffmpeg-location "/usr/bin/ffmpeg" \
    -f "bestaudio" \
    --extract-audio \
    --audio-quality 0 \
    --write-info-json \
    -o "%(title)s.%(ext)s" \
    -P "./" \
    --retries 10 \
    --cookies-from-browser firefox \
    --no-overwrites \
    "$url" 2>&1)

# Extract file names from output
json_file=$(echo "$ytdlp_output" | grep -oP 'Writing video metadata as JSON to: \K.*\.info\.json')
download_file=$(echo "$ytdlp_output" | grep -oP 'Destination: \K.*\.webm')
extracted_file=$(echo "$ytdlp_output" | grep -oP 'Destination: \K.*\.opus')
extracted_file_json="${extracted_file%.opus}.info.json"

# Read JSON file content
album=$(jq -r '.fulltitle' "$extracted_file_json")
artist=$(jq -r '.uploader' "$extracted_file_json")

# Create output directory
output_dir="./processed"
mkdir -p "$output_dir"

# Function to convert a name to a safe filename
convert_to_safe_filename() {
    echo "$1" | tr -d '"' | sed 's#[\/:*?<>|]#_#g'
}

# Function to generate a unique filename
get_unique_filename() {
    base_name="$1"
    extension="$2"
    counter=1
    unique_name="${base_name}.${extension}"
    while [ -e "$output_dir/$unique_name" ]; do
        unique_name="${base_name}_$counter.${extension}"
        ((counter++))
    done
    echo "$unique_name"
}

input_extension="${extracted_file##*.}"

# Check if JSON has chapters
if jq -e '.chapters' "$extracted_file_json" > /dev/null; then
    track_number=1
    total_tracks=$(jq '.chapters | length' "$extracted_file_json")
    
    # Process each chapter
    jq -c '.chapters[]' "$extracted_file_json" | while read -r chapter; do
        start=$(echo "$chapter" | jq '.start_time | floor')
        end=$(echo "$chapter" | jq '.end_time | floor')
        title=$(echo "$chapter" | jq -r '.title')

        # Convert title to safe filename
        safe_title=$(convert_to_safe_filename "$title")
        unique_filename=$(get_unique_filename "$safe_title" "$input_extension")
        output_file="$output_dir/$unique_filename"

        echo "Processing chapter: $title ($start - $end)"
        
        # Run ffmpeg to extract chapter
        ffmpeg -y -ss "$start" -i "$extracted_file" -to "$end" -c copy \
            -id3v2_version 3 \
            -metadata title="$title" \
            -metadata album="$album" \
            -metadata artist="$artist" \
            -metadata track="$track_number" \
            "$output_file"

        if [ $? -ne 0 ]; then
            echo "Error: Failed to process chapter '$title'. Skipping..."
        fi

        ((track_number++))
    done
else
    # Process entire file as a single track
    title=$(jq -r '.fulltitle' "$extracted_file_json")
    safe_title=$(convert_to_safe_filename "$title")
    unique_filename=$(get_unique_filename "$safe_title" "$input_extension")
    output_file="$output_dir/$unique_filename"

    echo "Processing single track: $title"
    
    # Run ffmpeg to add metadata
    ffmpeg -y -i "$extracted_file" -c copy \
        -id3v2_version 3 \
        -hide_banner \
        -metadata title="$title" \
        -metadata album="$album" \
        -metadata artist="$artist" \
        -metadata track="1/1" \
        -loglevel error \
        "$output_file"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to process file '$title'. Skipping..."
    fi
fi

echo "Processing complete! Files saved in '$output_dir' directory."