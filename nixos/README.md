## Periodic polling on NixOS

The flake also provides a NixOS module that periodically checks YouTube
channels and playlists for new videos, then transcribes videos that have not
previously completed successfully. Each run:

- reads the configured channel or playlist URLs;
- examines the full history of sources without an output directory and the
  newest 20 videos from existing sources;
- de-duplicates videos that appear in more than one source;
- writes each transcript below the configured output directory; and
- records successfully processed video IDs so later runs skip them.

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

The service stores its lock file and processed-video archive in
`/var/lib/transcriber`; the archive is `/var/lib/transcriber/processed.txt`.
Its output is in `outputDirectory`, with one directory per video containing
the downloaded subtitle file, metadata, and the generated `transcript.txt`
and `transcript.md` files.

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
