from yt_dlp import YoutubeDL

URLS = ['https://www.youtube.com/shorts/YNNv8FajA2o']
with YoutubeDL() as ydl:
    ydl.download(URLS)