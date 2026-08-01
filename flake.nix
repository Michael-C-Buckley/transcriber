{
  description = "Transcriber Nix Flake";

  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

  outputs = {nixpkgs, ...}: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    nixpkgsFor = forAllSystems (system: import nixpkgs {inherit system;});
  in {
    packages = forAllSystems (
      system: {
        default = nixpkgsFor.${system}.callPackage ./package.nix {};
      }
    );
  };
}
