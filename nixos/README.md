## Periodic polling on NixOS

The flake also provides a NixOS module that periodically checks YouTube
channels and playlists for new videos, then transcribes videos that have not
previously completed successfully. Each run:

- reads the configured channel or playlist URLs;
- examines the full history of every source using yt-dlp's flat-playlist mode;
- de-duplicates videos that appear in more than one source;
- writes each transcript below the configured output directory; and
- records successful and no-subtitle video IDs per source so later runs skip
  them.

Import the module from this flake and configure one or more sources:

```nix
{
	inputs.transcriber.url = "path:/path/to/ytdlp";

	outputs = { nixpkgs, transcriber, ... }: {
		nixosConfigurations.example = nixpkgs.lib.nixosSystem {
			modules = [
				transcriber.nixosModules.poll-service
				{
					services.transcriber-poll = {
						enable = true;
						sources = [
							"https://www.youtube.com/@example/videos"
							"https://www.youtube.com/playlist?list=PLAYLIST_ID"
						];
						calendar = "daily";
						outputDirectory = "/var/lib/transcriber/output";
						gitRemote = "git@github.com:example/transcripts.git";
					};
				}
			];
		};
	};
}
```

`calendar` accepts a systemd calendar expression, such as `hourly` or
`Mon *-*-* 09:00:00`. The timer adds up to ten minutes of randomized delay and
runs missed schedules after the machine next starts.

The service stores its runtime lock in `/var/lib/transcriber`. Durable state is
part of `outputDirectory`: every source has `.state/successful.txt` and
`.state/no-subs.txt`, so Git commits the poll decisions with the transcripts.
Videos without a downloadable English VTT subtitle are recorded in
`no-subs.txt` and skipped on later runs. Each video directory contains the
downloaded subtitle file, metadata, and the generated `transcript.txt` and
`transcript.md` files.

The service pulls `gitBranch` (`main` by default) before processing and pushes
a `Transcriber output` commit afterward. Configure authentication for the
`transcriber` system user; an unreachable remote or failed authentication
causes the run to fail without recording newly processed video IDs.

After rebuilding the NixOS configuration, inspect or run the service with:

```sh
systemctl list-timers transcriber-poll.timer
systemctl start transcriber-poll.service
journalctl -u transcriber-poll.service
```

Failed downloads are left out of the processed archive, so a future scheduled
run retries them. Concurrent runs are prevented with a lock file.
