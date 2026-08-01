{
  config,
  lib,
  pkgs,
  transcriber,
  ...
}: let
  cfg = config.services.transcriber-poll;

  poller = pkgs.writeShellApplication {
    name = "transcriber-poll";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.util-linux
      pkgs.yt-dlp
      transcriber
    ];

    text = builtins.readFile ./transcriber-poll.sh;
  };

  sourcesFile = pkgs.writeText "transcriber-sources" (
    lib.concatStringsSep "\n" cfg.sources
  );
in {
  options.services.transcriber-poll = {
    enable = lib.mkEnableOption "periodic video transcript ingestion";

    sources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Channel and playlist URLs to inspect.";
    };

    outputDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/transcriber/output";
    };

    scanLimit = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20;
    };

    calendar = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.transcriber-poll = {
      description = "Discover and transcribe new videos";

      serviceConfig = {
        Type = "oneshot";

        StateDirectory = "transcriber";
        StateDirectoryMode = "0750";

        WorkingDirectory = cfg.outputDirectory;

        ExecStart = lib.getExe poller;

        Environment = [
          "TRANSCRIBER_STATE_DIR=/var/lib/transcriber"
          "TRANSCRIBER_OUTPUT_DIR=${cfg.outputDirectory}"
          "TRANSCRIBER_SOURCES=${sourcesFile}"
          "TRANSCRIBER_SCAN_LIMIT=${toString cfg.scanLimit}"
        ];

        User = "transcriber";
        Group = "transcriber";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";

        ReadWritePaths = [
          "/var/lib/transcriber"
          cfg.outputDirectory
        ];
      };
    };

    systemd.timers.transcriber-poll = {
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.calendar;
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };

    users.users.transcriber = {
      isSystemUser = true;
      group = "transcriber";
      home = "/var/lib/transcriber";
    };

    users.groups.transcriber = {};
  };
}