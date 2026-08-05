{
  description = "Transcriber Nix Flake";

  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    nixpkgsFor = forAllSystems (
      system:
        import nixpkgs {
          inherit system;
          overlays = import ./overlays.nix;
        }
    );
  in {
    packages = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
      in {
        default = self.packages.${system}.transcriber;
        transcriber = pkgs.callPackage ./transcriber.nix {};
        poller = pkgs.callPackage ./poller.nix {};
        ytdlp-slim = pkgs.yt-dlp;
      }
    );
    devShells = forAllSystems (system: {
      default = import ./shell.nix {pkgs = nixpkgsFor.${system};};
    });

    nixosModules.poll-service = ./nixos/poll-service.nix;
  };
}
