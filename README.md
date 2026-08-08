# Transcriber

This is a simple tool I use for getting a Youtube's video subtitle track (English currently)
and parsing to usable text.
I mainly use it to convert long-form video essay content into a searchable form.

It uses `yt-dlp` to fetch available English (including auto-generated)
subtitles in WebVTT format, then removes caption overlap and groups the text
into timestamped paragraphs.

## Usage

Run it directly with Nix:

```sh
nix run . -- 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Or build the package first:

```sh
nix build
./result/bin/transcriber 'https://www.youtube.com/watch?v=VIDEO_ID'
```

The script creates a directory named after the video and its ID. It writes:

- `id.txt` — the stable video ID as a single line
- `source.md` — concise, Obsidian-compatible source metadata and links
- `source.en.vtt` — the downloaded English subtitles
- `source.info.json` — complete raw metadata from yt-dlp
- `transcript.md` — cleaned transcript with paragraph timestamps

The command requires a video with English subtitles available. If it is
restricted, private, or has no matching subtitles, `yt-dlp` will fail.
