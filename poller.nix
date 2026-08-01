{ pkgs }:
pkgs.writeShellApplication {
  name = "poller";
  runtimeInputs = builtins.attrValues {
    inherit (pkgs)
      coreutils
      gawk
      gnugrep
      util-linux
      yt-dlp
      ;
    transcriber = pkgs.callPackage ./transcriber.nix { };
  };
  text = builtins.readFile ./scripts/poller;
}
