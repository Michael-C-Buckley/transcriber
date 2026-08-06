## Poller

`poller` discovers recent videos from YouTube channel and playlist URLs, then
runs `transcriber` for videos it has not already processed. It inspects the
newest 20 videos from every configured source, removes duplicate video IDs,
and writes each transcript into a source-specific subdirectory of the output
directory. YouTube channel URLs use the channel name without the leading `@`;
for example, `https://www.youtube.com/@Channel` writes beneath
`$TRANSCRIBER_OUTPUT_DIR/Channel`.

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

The file uses `key=value` lines. Blank lines and lines beginning with `#` are
ignored. Environment variables remain available as overrides for compatibility:

```text
state_dir=/var/lib/transcriber
output_dir=/var/lib/transcriber/output
sources_file=/etc/transcriber/sources.txt
request_delay=1
video_delay=10
scan_limit=20
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

Successful video IDs are appended to `processed.txt` after local output is
written, or after a successful push when Git is enabled. A failed transcription,
commit, or push is not recorded and will be retried. The script uses `poll.lock`
to prevent concurrent polls; when a poll is already running, another invocation
exits successfully without doing work.
