#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def iso_date(value: Any) -> str | None:
    if not isinstance(value, str) or len(value) != 8 or not value.isdigit():
        return None

    return f"{value[:4]}-{value[4:6]}-{value[6:]}"


def display_duration(value: Any) -> str | None:
    if not isinstance(value, (int, float)):
        return None

    total = round(value)
    hours, remainder = divmod(total, 3600)
    minutes, seconds = divmod(remainder, 60)

    if hours:
        return f"{hours}:{minutes:02}:{seconds:02}"

    return f"{minutes}:{seconds:02}"


def yaml_value(value: Any) -> str:
    # JSON strings and scalars are also valid YAML and avoid hand-rolled
    # escaping for titles, URLs, and channel names.
    return json.dumps(value, ensure_ascii=False)


def optional_frontmatter(lines: list[str], key: str, value: Any) -> None:
    if value is not None and value != "":
        lines.append(f"{key}: {yaml_value(value)}")


def markdown_link(label: str, url: str) -> str:
    safe_label = label.replace("]", "\\]")
    safe_url = url.replace(")", "%29")
    return f"[{safe_label}]({safe_url})"


def write_provenance(info_path: Path) -> None:
    metadata = json.loads(info_path.read_text(encoding="utf-8"))
    video_id = metadata.get("id")

    if not isinstance(video_id, str) or not video_id:
        raise ValueError(f"Missing video ID in {info_path}")

    output_directory = info_path.parent
    title = metadata.get("title") or video_id
    url = metadata.get("webpage_url") or metadata.get("original_url")
    channel = metadata.get("channel") or metadata.get("uploader")
    channel_id = metadata.get("channel_id") or metadata.get("uploader_id")
    channel_url = metadata.get("channel_url") or metadata.get("uploader_url")
    published = iso_date(metadata.get("upload_date"))
    duration_seconds = metadata.get("duration")
    duration = display_duration(duration_seconds)
    platform_value = metadata.get("extractor_key") or metadata.get("extractor")
    platform = platform_value.lower() if isinstance(platform_value, str) else None

    frontmatter = ["---", 'type: "video-source"']
    optional_frontmatter(frontmatter, "platform", platform)
    optional_frontmatter(frontmatter, "video_id", video_id)
    optional_frontmatter(frontmatter, "source_url", url)
    optional_frontmatter(frontmatter, "title", title)
    optional_frontmatter(frontmatter, "channel", channel)
    optional_frontmatter(frontmatter, "channel_id", channel_id)
    optional_frontmatter(frontmatter, "channel_url", channel_url)
    optional_frontmatter(frontmatter, "published", published)
    optional_frontmatter(frontmatter, "duration_seconds", duration_seconds)
    frontmatter.append("---")

    body = [*frontmatter, "", f"# {title}", ""]

    if isinstance(url, str) and url:
        body.append(f"- Source: {markdown_link('Watch video', url)}")

    if isinstance(channel, str) and channel:
        if isinstance(channel_url, str) and channel_url:
            body.append(f"- Channel: {markdown_link(channel, channel_url)}")
        else:
            body.append(f"- Channel: {channel}")

    body.append(f"- Video ID: `{video_id}`")
    body.append("- Transcript: [transcript.md](transcript.md)")

    if published:
        body.append(f"- Published: {published}")

    if duration:
        body.append(f"- Duration: {duration}")

    (output_directory / "id.txt").write_text(f"{video_id}\n", encoding="utf-8")
    (output_directory / "source.md").write_text(
        "\n".join(body) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create concise provenance files from yt-dlp metadata",
    )
    parser.add_argument("info_json", type=Path)
    args = parser.parse_args()

    write_provenance(args.info_json)


if __name__ == "__main__":
    main()
