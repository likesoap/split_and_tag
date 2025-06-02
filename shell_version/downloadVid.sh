#!/bin/bash

# Check if a URL is provided as an argument
if [ $# -eq 0 ]; then
    echo "Usage: ./downloadVid.sh <video_url>"
    exit 1
fi

# Get the first argument as the video URL
videoURL="$1"
download_path=/home/$(whoami)/Downloads/yt

if [ ! -d "$download_path" ]; then
    echo "Directory does not exist. Creating: $download_path"
    mkdir -p "$download_path"

fi

# Define the yt-dlp command with the provided configuration
ytdlpCommand=(
    yt-dlp
    --ffmpeg-location "/usr/bin/ffmpeg" # Adjust if ffmpeg is in a different location
    -f "bv*[height<=1080]+ba"           # Video format selection: best video up to 1080p + best audio
    --yes-playlist                      # Automatically downloads all videos in a playlist if the URL is a playlist
    --sub-langs all                     # Downloads all available subtitles for the video
    --retries 10                        # Retries the download up to 10 times in case of failure
    --cookies-from-browser firefox      # Uses cookies from the Firefox browser for authentication
    -o "%(title)s.%(ext)s"              # Output filename template: uses video title and extension
    -P "${download_path}"   # Sets the download directory (adjust path as needed)
    --no-overwrites                     # Prevents overwriting existing files
    "$videoURL"                         # Adds the user-provided URL
)

# Execute the yt-dlp command
"${ytdlpCommand[@]}"
