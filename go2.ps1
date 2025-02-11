param (
    [string]$url
)

# Check if URL is provided
if (-not $url) {
    Write-Host "Usage: .\yt-dlp-download.ps1 <URL>"
    exit 1
}

# Define yt-dlp command with configurations
$ytdlpCommand = @(
    "yt-dlp",
    "--ffmpeg-location `"C:\\ProgramData\\chocolatey\\bin\\ffmpeg.exe`"",
    "-f `"bestaudio`"",
    "--extract-audio",
    "--audio-quality 0",
    "--write-info-json",
    "-o `"%(title)s.%(ext)s`"",
    "-P `"D:\\Music\\download\\`"",
    "--retries 10",
    "--cookies-from-browser firefox",
    "--no-overwrites",
    "`"$url`""
) -join " "

# Execute the command and Run the yt-dlp command and capture its output
$ytdlpOutput = & Invoke-Expression $ytdlpCommand 2>&1 | Out-String

# Define regex patterns to extract file names
$jsonFilePattern = 'Writing video metadata as JSON to: (.+\.info\.json)'
$downloadFilePattern = 'Destination: (.+\.webm)'
$extractedFilePattern = 'Destination: (.+\.opus)'

# Extract file names using regex
$jsonFile = [regex]::Match($ytdlpOutput, $jsonFilePattern).Groups[1].Value
$downloadFile = [regex]::Match($ytdlpOutput, $downloadFilePattern).Groups[1].Value
$extractedFile = [regex]::Match($ytdlpOutput, $extractedFilePattern).Groups[1].Value
$extractedFileJson = $extractedFile -replace '\.opus$', '.info.json'


# Output the extracted file names
Write-Host "JSON Metadata File: $jsonFile"
Write-Host "Downloaded File: $downloadFile"
Write-Host "Extracted Audio File: $extractedFile"
Write-Host "Extracted Audio File Json: $extractedFileJson"


#combining the first script


$inputFile = $extractedFile
$jsonFile = $extractedFileJson

# Read JSON file content
$jsonContent = Get-Content -Path $jsonFile -Raw | ConvertFrom-Json

# Read album and artist from JSON
$album = $jsonContent.fulltitle
$artist = $jsonContent.uploader

# Create the output directory
$outputDir = "./processed"
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Function to convert a name to a safe filename
function ConvertTo-SafeFilename {
    param (
        [string]$name
    )
    # Remove double quotes
    $name = $name -replace '"', ''
    # Replace other invalid characters with underscores
    $safeName = $name -replace '[\\/:*?<>|]', '_'
    return $safeName
}

# Function to generate a unique filename
function Get-UniqueFilename {
    param (
        [string]$baseName,
        [string]$extension
    )
    $counter = 1
    $uniqueName = "$baseName.$extension"
    while (Test-Path -Path (Join-Path -Path $outputDir -ChildPath $uniqueName)) {
        $uniqueName = "${baseName}_$counter.$extension"
        $counter++
    }
    return $uniqueName
}

# Get the input file's extension
$inputExtension = [System.IO.Path]::GetExtension($inputFile).TrimStart('.')

# Check if the JSON has a 'chapters' key
if ($jsonContent.PSObject.Properties.Name -contains "chapters") {
    # Process each chapter
    $trackNumber = 1
    # $totalTracks = $jsonContent.chapters.Count  # Total number of tracks is the number of chapters
    

    foreach ($chapter in $jsonContent.chapters) {
        $start = [math]::Floor($chapter.start_time)
        $end = [math]::Floor($chapter.end_time)
        $title = $chapter.title

        # Convert the title to a safe filename
        $safeTitle = ConvertTo-SafeFilename -name $title

        # Generate a unique filename
        $baseName = $safeTitle
        $extension = $inputExtension
        $uniqueFilename = Get-UniqueFilename -baseName $baseName -extension $extension
        $outputFile = Join-Path -Path $outputDir -ChildPath $uniqueFilename

        # Debugging: Print chapter details
        Write-Host "Processing chapter:"
        Write-Host "  Track Number: $trackNumber"
        Write-Host "  Title: $title"
        Write-Host "  Safe Title: $safeTitle"
        Write-Host "  Start: $start"
        Write-Host "  End: $end"
        Write-Host "  Output: $outputFile"

        # Run ffmpeg to extract the chapter without transcoding
        $ffmpegCommand = "ffmpeg -y -ss $start -i `"$inputFile`" -to $end -c copy " +
                         "-id3v2_version 3 " +
                         "-metadata title='$title' " +
                         "-metadata album='$album' " +
                         "-metadata artist='$artist' " +
                         "-metadata track='$trackNumber' " +
                         "`"$outputFile`""
        Write-Host "Executing: $ffmpegCommand"
        Invoke-Expression -Command $ffmpegCommand

        # Check if ffmpeg succeeded
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to process chapter '$title'. Skipping..."
        }

        # Increment track number for the next chapter
        $trackNumber++
    }
} else {
    # Process the entire file as a single track
    $title = $jsonContent.fulltitle

    # Convert the title to a safe filename
    $safeTitle = ConvertTo-SafeFilename -name $title

    # Generate a unique filename
    $baseName = $safeTitle
    $extension = $inputExtension
    $uniqueFilename = Get-UniqueFilename -baseName $baseName -extension $extension
    $outputFile = Join-Path -Path $outputDir -ChildPath $uniqueFilename

    # Debugging: Print file details
    Write-Host "Processing single track:"
    Write-Host "  Title: $title"
    Write-Host "  Safe Title: $safeTitle"
    Write-Host "  Output: $outputFile"

    # Run ffmpeg to add metadata to the entire file
    $ffmpegCommand = "ffmpeg -y -i `"$inputFile`" -c copy " +
                     "-id3v2_version 3 " +
                     "-hide_banner " +
                     "-metadata title='$title' " +
                     "-metadata album='$album' " +
                     "-metadata artist='$artist' " +
                     "-metadata track='1/1' " +
                     "-loglevel error " +
                     "`"$outputFile`""
    Write-Host "Executing: $ffmpegCommand"
    Invoke-Expression -Command $ffmpegCommand

    # Check if ffmpeg succeeded
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to process file '$title'. Skipping..."
    }
}

Write-Host "Processing complete! Files saved in '$outputDir' directory."