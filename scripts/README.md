## Poller

`poller` discovers videos from YouTube channel and playlist URLs, then runs
`transcriber` for videos it has not already processed. Every run asks yt-dlp for
the source's full history using flat-playlist extraction. yt-dlp parses the
source list first and exposes video IDs and URLs without extracting or
downloading every individual video. The poller removes duplicate video IDs and
writes each transcript into a source-specific subdirectory of the output
directory. YouTube channel URLs use the channel name without the leading `@`;
for example,
`https://www.youtube.com/@Channel` writes beneath
`$TRANSCRIBER_OUTPUT_DIR/Channel`.

Each source directory contains checked-in poller state:

```text
Channel/
  .state/
    successful.txt
    no-subs.txt
  Video title [VIDEO_ID]/
    ...
```

`successful.txt` records videos whose output was created, while `no-subs.txt`
records videos for which the transcriber could not download English subtitles.
When Git synchronization is enabled, state and transcript output are committed
and pushed together.

Git synchronization is optional. When enabled, the poller initializes the
output directory as a repository when necessary, fetches and pulls the
configured branch, and replaces a diverged local branch with the remote branch.
After processing, it commits all output changes and pushes them to `origin`.

Create a source file containing one URL per line. Blank lines and lines that
begin with `#` are ignored:

```text
# Channels and playlists to poll
https://www.youtube.com/@example/videos
https://www.youtube.com/playlist?list=PLAYLIST_ID
```

Run the packaged script with a configuration file:

```sh
TRANSCRIBER_CONFIG="$PWD/config" nix run .#poller
```

To run one poll locally with this checkout's existing `sources.txt`, `output/`,
and `state/` directories, with Git synchronization disabled, run:

```sh
./scripts/run-local-poller
```

To manually retry only the video IDs recorded in source-local
`.state/no-subs.txt` files, run:

```sh
./scripts/run-local-missing-subtitles
```

This manual retry invokes the transcriber only for IDs in each source's
`.state/no-subs.txt`. A successful retry adds the ID to `successful.txt` and
removes it from `no-subs.txt`. Scheduled pollers do not enable this retry mode.

## Container publishing

Build and publish the `linux/amd64` and `linux/arm64` images to GHCR with the
full current Git commit SHA and `latest` tags:

```sh
GHCR_TOKEN=github_pat_... ./scripts/push-container
```

The token must have `write:packages` permission (and repository access if the
package is private). Cross-platform builds require Podman to have a working
QEMU/binfmt setup for the non-native target architecture.

The file uses `key=value` lines. Blank lines and lines beginning with `#` are
ignored. Environment variables remain available as overrides for compatibility:

```text
runtime_dir=/var/lib/transcriber
output_dir=/var/lib/transcriber/output
sources_file=/etc/transcriber/sources.txt
request_delay=1
video_delay=10
git_enabled=false
git_remote=
git_branch=main
git_commit_message=Transcriber output
git_author_name=Transcriber
git_author_email=transcriber@localhost
```

The default configuration path is `/etc/transcriber/config`. Each setting can
be overridden by its uppercase `TRANSCRIBER_` equivalent; for example,
`git_enabled` maps to `TRANSCRIBER_GIT_ENABLED`. Git is disabled by default.
When enabled, `git_remote` is required only if the output repository does not
already have an `origin` remote.

`runtime_dir` contains only the poll lock and temporary files; durable polling
state lives under the output directory. `state_dir` and
`TRANSCRIBER_STATE_DIR` remain accepted as compatibility aliases for
`runtime_dir`. Existing `processed.txt` and
`missing-english-subtitles.txt` files there are read and migrated into the
source-local state files as matching videos are discovered.

For unattended HTTPS authentication, set `TRANSCRIBER_GIT_TOKEN` to a personal
access token with write access to the output repository. The optional
`TRANSCRIBER_GIT_USERNAME` defaults to `x-access-token`. These credentials are
environment-only settings and cannot be placed in the configuration file.

Successful video IDs are appended to the source's `.state/successful.txt` as
soon as local output is written. Videos for which the transcriber reports that
it could not find a downloaded English VTT subtitle are recorded in
`.state/no-subs.txt` and skipped on later runs. Other failed transcriptions are
not recorded and will be retried. The script uses `poll.lock` in `runtime_dir`
to prevent concurrent polls; when a poll is already running, another invocation
exits successfully without doing work.
