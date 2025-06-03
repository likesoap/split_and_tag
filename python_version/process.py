#!/usr/bin/python3

import os
import json
import math
import subprocess
import re
import shutil

output_dir = "output"
output_format = "opus"
processed_dir = "processed"


def sanitize_metadata(text):
    return re.sub(r'[\\/:"*?<>|]', "_", text).strip()


# entries = os.listdir(".")
# files = [f for f in entries if os.path.isfile(f)]


def move_files_to_processed(audio_file, json_file, processed_dir, name=None):
    """
    Moves the specified audio and JSON files to the processed directory.
    
    Parameters:
    - audio_file (str): Path to the audio file.
    - json_file (str): Path to the JSON file.
    - processed_dir (str): Directory where the files should be moved.
    - name (str, optional): Name to display in the status message.
    """
    os.makedirs(processed_dir, exist_ok=True)

    destination_audio_path = os.path.join(processed_dir,
                                          os.path.basename(audio_file))
    destination_json_path = os.path.join(processed_dir,
                                         os.path.basename(json_file))

    # Remove existing destination files if duplicates
    if os.path.exists(destination_audio_path):
        os.remove(destination_audio_path)
    if os.path.exists(destination_json_path):
        os.remove(destination_json_path)

    # Move the files
    shutil.move(audio_file, processed_dir)
    shutil.move(json_file, processed_dir)

    # Status message
    display_name = name or os.path.basename(audio_file)
    print(f"🆒 Moved '{display_name}' to '{processed_dir}'")


for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".info.json"):
            name = file.removesuffix(".info.json")
            json_file = os.path.join(root, f"{name}.info.json")
            opus_file = os.path.join(root, f"{name}.opus")
            m4a_file = os.path.join(root, f"{name}.m4a")

            try:
                with open(json_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError):
                print(
                    f"Warning: Invalid or missing JSON in '{json_file}'. Skipping..."
                )
                continue

            if os.path.exists(opus_file):
                audio_file = opus_file
            else:
                print(
                    f"❌Warning: Missing audio file / Unsupported format for '{name}'. Skipping..."
                )
                continue

            if "chapters" in data and data["chapters"]:
                print(f"✅ Processing chapters for: {audio_file}")
                chapters = data["chapters"]

                for i, chapter in enumerate(chapters):
                    chapter_start = math.floor(
                        float(chapter.get("start_time", 0)))
                    chapter_end = math.floor(float(chapter.get("end_time", 0)))
                    chapter_album = data.get("title", "Unknown Album")
                    chapter_artist = data.get("uploader", "Unknown Artist")
                    chapter_title = chapter.get("title", "Unknown Title")
                    chapter_track_number = i + 1

                    safe_album = sanitize_metadata(chapter_album)
                    safe_title = sanitize_metadata(chapter_title)

                    chapter_song_target_dir = os.path.join(
                        output_dir, safe_album)
                    chapter_song_target_file = os.path.join(
                        chapter_song_target_dir,
                        f"{safe_title}.{output_format}")

                    if os.path.isfile(chapter_song_target_file):
                        print(
                            f"Skipping existing file: {chapter_song_target_file}"
                        )
                        move_files_to_processed(audio_file, json_file,
                                                processed_dir, name)
                        continue

                    os.makedirs(chapter_song_target_dir, exist_ok=True)

                    cmd = [
                        "ffmpeg",
                        "-y",
                        "-ss",
                        str(chapter_start),
                        "-i",
                        audio_file,
                        "-to",
                        str(chapter_end),
                        "-c",
                        "copy",
                        "-id3v2_version",
                        "3",
                        "-metadata",
                        f"title={chapter_title}",
                        "-metadata",
                        f"album={chapter_album}",
                        "-metadata",
                        f"artist={chapter_artist}",
                        "-metadata",
                        f"track={chapter_track_number}",
                        "-loglevel",
                        "quiet",
                        "-nostats",
                        chapter_song_target_file,
                    ]

                    subprocess.run(cmd, check=True)
                    print(
                        f"✅ Processing complete! Saved: {chapter_song_target_file}"
                    )

                    move_files_to_processed(audio_file, json_file,
                                            processed_dir, name)
            else:
                # Fallback: single track file
                album = data.get("playlist_title",
                                 data.get("title", "Unknown Album"))
                artist = data.get("uploader", "Unknown Artist")
                title = data.get("title", "Unknown Title")
                track_number = data.get("playlist_index", 1)

                safe_album = sanitize_metadata(album)
                safe_title = sanitize_metadata(title)

                song_target_dir = os.path.join(output_dir, safe_album)
                song_target_file = os.path.join(
                    song_target_dir, f"{safe_title}.{output_format}")

                if os.path.isfile(song_target_file):
                    print(f"Skipping existing file: {song_target_file}")
                    continue

                os.makedirs(song_target_dir, exist_ok=True)

                cmd = [
                    "ffmpeg",
                    "-y",
                    "-i",
                    audio_file,
                    "-c",
                    "copy",
                    "-id3v2_version",
                    "3",
                    "-metadata",
                    f"title={safe_title}",
                    "-metadata",
                    f"album={safe_album}",
                    "-metadata",
                    f"artist={artist}",
                    "-metadata",
                    f"track={track_number}",
                    "-loglevel",
                    "quiet",
                    "-nostats",
                    song_target_file,
                ]

                subprocess.run(cmd, check=True)
                print(f"✅ Processing complete! Saved: {song_target_file}")

                move_files_to_processed(audio_file, json_file, processed_dir,
                                        name)
    break
