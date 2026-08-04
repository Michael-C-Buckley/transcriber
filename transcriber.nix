{pkgs}: let
  inherit (pkgs.lib) getExe;
  inherit (pkgs) yt-dlp python3;
in
  pkgs.writeShellApplication {
    name = "transcriber";
    text = ''
      url="''${1:?Usage: transcriber URL}"

      # Fetch the desired video source
      output="$(${getExe yt-dlp} \
        --no-simulate \
        --no-playlist \
        --skip-download \
        --write-subs \
        --write-auto-subs \
        --sub-langs 'en.*,-live_chat' \
        --sub-format 'vtt/best' \
        --write-info-json \
        --output '%(title).160B [%(id)s]/source.%(ext)s' \
        --print '%(title).160B [%(id)s]/source.en.vtt' \
        "$url")"

      if [ -z "$output" ] || [ ! -f "$output" ]; then
        echo "Could not find the downloaded English VTT subtitle: $output" >&2
        exit 1
      fi

      # Normalize the text for use
      ${getExe python3} ${./scripts/transcript.py} "$output"
    '';
  }
