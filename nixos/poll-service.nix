{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.transcriber-poll;

  sourcesFile = pkgs.writeText "transcriber-sources" (lib.concatStringsSep "\n" cfg.sources);
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

    gitRemote = lib.mkOption {
      type = lib.types.str;
      description = "Git remote URL used to pull and push transcript output.";
    };

    gitBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git branch used for transcript output.";
    };

    calendar = lib.mkOption {
      type = lib.types.str;
      default = "daily";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd = {
      services.transcriber-poll = {
        description = "Discover and transcribe new videos";

        serviceConfig = {
          Type = "oneshot";

          StateDirectory = "transcriber";
          StateDirectoryMode = "0750";

          WorkingDirectory = cfg.outputDirectory;

          ExecStart = lib.getExe (pkgs.callPackage ../poller.nix {});

          Environment = [
            "TRANSCRIBER_RUNTIME_DIR=/var/lib/transcriber"
            "TRANSCRIBER_OUTPUT_DIR=${cfg.outputDirectory}"
            "TRANSCRIBER_SOURCES=${sourcesFile}"
            "TRANSCRIBER_GIT_ENABLED=true"
            "TRANSCRIBER_GIT_REMOTE=${cfg.gitRemote}"
            "TRANSCRIBER_GIT_BRANCH=${cfg.gitBranch}"
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

      timers.transcriber-poll = {
        wantedBy = ["timers.target"];

        timerConfig = {
          OnCalendar = cfg.calendar;
          Persistent = true;
          RandomizedDelaySec = "10m";
        };
      };

      tmpfiles.rules = [
        "d /var/lib/transcriber 0750 transcriber transcriber -"
        "d ${config.services.transcriber-poll.outputDirectory} 0750 transcriber transcriber -"
      ];
    };

    users.users.transcriber = {
      isSystemUser = true;
      group = "transcriber";
      home = "/var/lib/transcriber";
    };

    users.groups.transcriber = {};
  };
}
