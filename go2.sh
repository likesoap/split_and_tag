#only download the full file and the json file:

#!/bin/bash

# Check if URL is provided
if [ -z "$1" ]; then
    echo "Usage: ./go2.sh '<URL>' #URL must be wrapped between a pair of '"
    exit 1
fi


#check for dependency
required_cmds=("yt-dlp" "jq" "ffmpeg")

for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed." >&2
        exit 1
    fi
done


#main body

url="$1"

ytdlp_output=(yt-dlp \
    -f "bestaudio" \
    --extract-audio \
    --yes-playlist \
    --audio-quality 0 \
    --write-info-json \
    -o "%(title)s.%(ext)s" \
    -P "./" \
    --retries 10 \
    --cookies-from-browser firefox \
    --no-overwrites \
    "$url")

"${ytdlp_output[@]}"
