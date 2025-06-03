#!/usr/bin/python3

import os
import json
import math
import subprocess
import re

output_dir = "output"
output_format = "opus"


def sanitize_metadata(text):
    return re.sub(r'[\\/:"*?<>|]', "_", text).strip()


# entries = os.listdir(".")
# files = [f for f in entries if os.path.isfile(f)]

for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".info.json"):
            name = file.removesuffix(".info.json")
            json_file = os.path.join(root, f"{name}.info.json")
            audio_file = os.path.join(root, f"{name}.opus")

            try:
                with open(json_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError):
                print(
                    f"Warning: Invalid or missing JSON in '{json_file}'. Skipping..."
                )
                continue

            if not os.path.isfile(audio_file):
                print(f"Warning: Missing audio file for '{name}'. Skipping...")
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
    break
