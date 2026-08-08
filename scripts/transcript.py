#!/usr/bin/env python3

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

TIMESTAMP = re.compile(
    r"(?P<hours>\d{2}):(?P<minutes>\d{2}):(?P<seconds>\d{2})[.,](?P<millis>\d{3})"
)
TAG = re.compile(r"<[^>]+>")
SPACE = re.compile(r"\s+")
ANNOTATION = re.compile(r"^\s*[\[(].*?[\])]\s*$")


def timestamp_seconds(value: str) -> float:
    match = TIMESTAMP.search(value)
    if not match:
        raise ValueError(f"Invalid VTT timestamp: {value}")

    return (
        int(match["hours"]) * 3600
        + int(match["minutes"]) * 60
        + int(match["seconds"])
        + int(match["millis"]) / 1000
    )


def display_timestamp(seconds: float) -> str:
    total = int(seconds)
    hours, remainder = divmod(total, 3600)
    minutes, seconds = divmod(remainder, 60)

    if hours:
        return f"{hours}:{minutes:02}:{seconds:02}"

    return f"{minutes}:{seconds:02}"


def clean_caption(lines: list[str]) -> str:
    text = " ".join(lines)
    text = TAG.sub("", text)
    text = html.unescape(text)
    text = SPACE.sub(" ", text).strip()

    if ANNOTATION.fullmatch(text):
        return ""

    return text


def remove_rolling_overlap(previous: str, current: str) -> str:
    """Remove words repeated from the end of the previous caption."""

    previous_words = previous.split()
    current_words = current.split()

    max_overlap = min(len(previous_words), len(current_words))

    for size in range(max_overlap, 0, -1):
        if previous_words[-size:] == current_words[:size]:
            return " ".join(current_words[size:])

    return current


def parse_vtt(path: Path) -> list[tuple[float, str]]:
    cues: list[tuple[float, str]] = []
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    index = 0

    while index < len(lines):
        line = lines[index].strip()

        if "-->" not in line:
            index += 1
            continue

        start = timestamp_seconds(line.split("-->", 1)[0].strip())
        index += 1
        caption_lines: list[str] = []

        while index < len(lines) and lines[index].strip():
            caption_lines.append(lines[index].strip())
            index += 1

        text = clean_caption(caption_lines)

        if text:
            cues.append((start, text))

    return cues


def normalize(cues: list[tuple[float, str]]) -> list[tuple[float, str]]:
    normalized: list[tuple[float, str]] = []
    accumulated = ""

    for timestamp, caption in cues:
        addition = remove_rolling_overlap(accumulated, caption)

        if not addition:
            continue

        if normalized and addition == normalized[-1][1]:
            continue

        normalized.append((timestamp, addition))
        accumulated = f"{accumulated} {addition}".strip()

        # Only recent text is needed for overlap detection.
        accumulated = " ".join(accumulated.split()[-50:])

    return normalized


def make_paragraphs(
    cues: list[tuple[float, str]],
    paragraph_seconds: int,
) -> list[tuple[float, str]]:
    paragraphs: list[tuple[float, str]] = []
    parts: list[str] = []
    paragraph_start: float | None = None

    for timestamp, text in cues:
        if paragraph_start is None:
            paragraph_start = timestamp

        if parts and timestamp - paragraph_start >= paragraph_seconds:
            paragraphs.append((paragraph_start, " ".join(parts)))
            parts = []
            paragraph_start = timestamp

        parts.append(text)

    if parts and paragraph_start is not None:
        paragraphs.append((paragraph_start, " ".join(parts)))

    return paragraphs


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument(
        "--paragraph-seconds",
        type=int,
        default=60,
        help="Approximate duration represented by each paragraph",
    )
    args = parser.parse_args()

    cues = normalize(parse_vtt(args.input))
    paragraphs = make_paragraphs(cues, args.paragraph_seconds)

    output_directory = args.input.parent

    markdown = (
        "\n\n".join(
            f"**[{display_timestamp(timestamp)}]** {text}"
            for timestamp, text in paragraphs
        )
        + "\n"
    )

    (output_directory / "transcript.md").write_text(
        markdown,
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
