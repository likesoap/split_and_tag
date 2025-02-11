### **Script Report**

#### **1. Script Overview**
The script performs the following tasks:
1. Downloads audio from a provided URL using `yt-dlp`.
2. Extracts metadata and file paths from the `yt-dlp` log output.
3. Processes the downloaded audio file using `ffmpeg`:
   - If the audio file has chapters, it splits the file into individual tracks based on chapters.
   - If no chapters are present, it processes the entire file as a single track.
4. Adds metadata (title, album, artist, track number) to the output files.
5. Saves the processed files in a specified output directory.

---

### **2. Syntax and Functionality Analysis**

#### **2.1. Parameters and Input Validation**
```powershell
param (
    [string]$url  # Define a parameter for the URL
)

# Check if URL is provided
if (-not $url) {
    Write-Host "Usage: .\yt-dlp-download.ps1 <URL>"
    exit 1  # Exit the script with an error code if no URL is provided
}
```
- **`param ([string]$url)`**:
  - Defines a script parameter `$url` to accept a URL as input.
- **`if (-not $url)`**:
  - Checks if the `$url` parameter is empty.
  - If no URL is provided, the script displays usage instructions and exits with an error code (`exit 1`).

---

#### **2.2. Define and Execute `yt-dlp` Command**
```powershell
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
) -join " "  # Join the array into a single command string

# Execute the command and capture its output
$ytdlpOutput = & $ytdlpCommand 2>&1 | Out-String
```
- **`$ytdlpCommand`**:
  - Constructs the `yt-dlp` command as an array of strings and joins them into a single command string.
  - Configurations include:
    - `--ffmpeg-location`: Specifies the path to `ffmpeg.exe`.
    - `-f "bestaudio"`: Downloads the best available audio quality.
    - `--extract-audio`: Extracts audio from the video.
    - `--audio-quality 0`: Sets the highest audio quality.
    - `--write-info-json`: Saves metadata as a JSON file.
    - `-o "%(title)s.%(ext)s"`: Names the output file using the video title.
    - `-P "D:\Music\download\"`: Specifies the output directory.
    - `--retries 10`: Retries failed downloads up to 10 times.
    - `--cookies-from-browser firefox`: Uses cookies from Firefox for age-restricted content.
    - `--no-overwrites`: Avoids overwriting existing files.
- **`& $ytdlpCommand 2>&1 | Out-String`**:
  - Executes the `yt-dlp` command and captures both standard output and error streams into a single string (`$ytdlpOutput`).

---

#### **2.3. Extract File Names from Log Output**
```powershell
# Define regex patterns to extract file names
$jsonFilePattern = 'Writing video metadata as JSON to: (.+\.info\.json)'
$downloadFilePattern = 'Destination: (.+\.webm)'
$extractedFilePattern = 'Destination: (.+\.opus)'

# Extract file names using regex
$jsonFile = [regex]::Match($ytdlpOutput, $jsonFilePattern).Groups[1].Value
$downloadFile = [regex]::Match($ytdlpOutput, $downloadFilePattern).Groups[1].Value
$extractedFile = [regex]::Match($ytdlpOutput, $extractedFilePattern).Groups[1].Value
$extractedFileJson = $extractedFile -replace '\.opus$', '.info.json'
```
- **Regex Patterns**:
  - `$jsonFilePattern`: Matches the JSON metadata file path.
  - `$downloadFilePattern`: Matches the downloaded `.webm` file path.
  - `$extractedFilePattern`: Matches the extracted `.opus` file path.
- **Regex Extraction**:
  - Uses `[regex]::Match()` to extract file paths from the log output.
- **File Renaming**:
  - `$extractedFileJson`: Renames the `.opus` file to `.info.json` for metadata processing.

---

#### **2.4. Output Extracted File Names**
```powershell
# Output the extracted file names
Write-Host "JSON Metadata File: $jsonFile"
Write-Host "Downloaded File: $downloadFile"
Write-Host "Extracted Audio File: $extractedFile"
Write-Host "Extracted Audio File Json: $extractedFileJson"
```
- Displays the extracted file paths for verification.

---

#### **2.5. Process Audio File with `ffmpeg`**
```powershell
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
```
- **`Get-Content -Path $jsonFile -Raw | ConvertFrom-Json`**:
  - Reads the JSON metadata file and converts it into a PowerShell object.
- **`$album` and `$artist`**:
  - Extracts the album title and artist name from the JSON metadata.
- **`New-Item -ItemType Directory`**:
  - Creates the output directory (`./processed`) if it doesn’t already exist.

---

#### **2.6. Functions for Safe Filenames and Unique Names**
```powershell
# Function to convert a name to a safe filename
function ConvertTo-SafeFilename {
    param (
        [string]$name
    )
    $name = $name -replace '"', ''
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
```
- **`ConvertTo-SafeFilename`**:
  - Removes invalid characters from filenames and replaces them with underscores.
- **`Get-UniqueFilename`**:
  - Generates a unique filename by appending a counter if a file with the same name already exists.

---

#### **2.7. Process Chapters or Single Track**
```powershell
# Check if the JSON has a 'chapters' key
if ($jsonContent.PSObject.Properties.Name -contains "chapters") {
    # Process each chapter
    $trackNumber = 1
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
                     "-loglevel eror " +
                     "`"$outputFile`""
    Write-Host "Executing: $ffmpegCommand"
    Invoke-Expression -Command $ffmpegCommand

    # Check if ffmpeg succeeded
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to process file '$title'. Skipping..."
    }
}
```
- **Chapter Processing**:
  - If the JSON metadata contains chapters, the script processes each chapter as a separate track.
  - Uses `ffmpeg` to extract chapters and add metadata.
- **Single Track Processing**:
  - If no chapters are present, the script processes the entire file as a single track.
  - Adds metadata (title, album, artist, track number) to the file.

---

#### **2.8. Final Output**
```powershell
Write-Host "Processing complete! Files saved in '$outputDir' directory."
```
- Displays a completion message with the output directory.

---

### **3. Potential Issues and Fixes**
1. **`-loglevel eror` Typo**:
   - Incorrect: `-loglevel eror`
   - Correct: `-loglevel error`
   - Fix: Update the `ffmpeg` command to use the correct log level.

2. **`Invoke-Expression` Security Risk**:
   - Using `Invoke-Expression` to execute commands can be risky if the input is not sanitized.
   - Fix: Use `Start-Process` or direct command execution (`&`) instead.

3. **Missing Error Handling**:
   - The script does not handle cases where `yt-dlp` or `ffmpeg` fails completely.
   - Fix: Add error handling using `try/catch` blocks.

4. **Hardcoded Paths**:
   - The `ffmpeg` path and output directory are hardcoded.
   - Fix: Make these configurable via parameters or environment variables.

---

### **4. Recommendations**
- Add input validation for the URL format.
- Use `Start-Process` instead of `Invoke-Expression` for better security.
- Add logging to a file for debugging purposes.
- Make paths configurable for flexibility.

