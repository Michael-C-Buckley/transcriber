{pkgs}:
pkgs.writeShellApplication {
  name = "poller";
  runtimeInputs = builtins.attrValues {
    inherit
      (pkgs)
      coreutils
      gawk
      git
      gnugrep
      openssh
      util-linux
      yt-dlp
      ;
    gitAskPass = pkgs.writeShellApplication {
      name = "transcriber-git-askpass";
      text = ''
        case "''${1:-}" in
          *Username* | *username*)
            printf '%s\n' "''${TRANSCRIBER_GIT_USERNAME:-x-access-token}"
            ;;
          *Password* | *password*)
            printf '%s\n' "''${TRANSCRIBER_GIT_TOKEN:?TRANSCRIBER_GIT_TOKEN is required}"
            ;;
          *)
            echo "Unexpected Git credential prompt: ''${1:-}" >&2
            exit 1
            ;;
        esac
      '';
    };
    transcriber = pkgs.callPackage ./transcriber.nix {};
  };
  text = builtins.readFile ./scripts/poller;
}
