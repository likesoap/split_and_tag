# Check if a URL is provided as an argument
if ($args.Count -eq 0) {
    Write-Host "Usage: script.ps1 <video_url>"
    exit
}

# Get the first argument as the video URL
$videoURL = $args[0]

# Define the yt-dlp command with the provided configuration
$ytdlpCommand = @(
    "yt-dlp", # The command to run yt-dlp
    "--ffmpeg-location `"D:\\ffmpeg-7.1.1-essentials_build\\bin\\ffmpeg.exe`"", # Specifies the path to ffmpeg.exe for post-processing
    "-f `"bv*[height<=1080]+ba`"", # Video format selection: best video up to 1080p + best audio
    "--yes-playlist", # Automatically downloads all videos in a playlist if the URL is a playlist
    "--sub-langs all", # Downloads all available subtitles for the video
    "--retries 10", # Retries the download up to 10 times in case of failure
    "--cookies-from-browser firefox", # Uses cookies from the Firefox browser for authentication (e.g., age-restricted videos)
    "-o `"%(title)s.%(ext)s`"", # Output filename template: uses video title and extension
    "-P `"D:\\Download\\yt\\`"", # Sets the download directory to "D:\Download\yt"
    "--no-overwrites", # Prevents overwriting existing files in the download directory
    "`"$videoURL`"" # Adds the user-provided URL
) -join " "

# Execute the yt-dlp command
Invoke-Expression $ytdlpCommand
