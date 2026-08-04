{
  description = "Transcriber Nix Flake";

  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      overlays = [
        (final: prev: {
          yt-dlp = prev.yt-dlp.override {
            # Not needed when only downloading subtitle and metadata files.
            ffmpegSupport = false;
            atomicparsleySupport = false;
            rtmpSupport = false;

            # Not needed unless using --cookies-from-browser with a
            # Secret Service-backed browser profile.
            withSecretStorage = false;

            # Much smaller than the default Deno runtime.
            jsRuntime = final.quickjs-ng;
          };
        })
      ];

      nixpkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system overlays;
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = self.packages.${system}.transcriber;
          transcriber = pkgs.callPackage ./transcriber.nix { };
          poller = pkgs.callPackage ./poller.nix { };
        }
      );

      nixosModules.poll-service = ./nixos/poll-service.nix;
    };
}
