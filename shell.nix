# This is a simple set of tools that doesn't require pinning, just get them from the host
{
  pkgs ? import <nixpkgs> {},
  extraPkgs ? [],
  ...
}:
pkgs.mkShellNoCC {
  name = "default";
  buildInputs = with pkgs;
    [
      # Nix
      alejandra
      deadnix
      nil

      # Yaml
      yamlfmt
      yamllint

      # Formatting
      mdformat
      shfmt
      ruff

      # Hooks
      lefthook
      shellcheck
      typos
      just
    ]
    ++ extraPkgs;

  # Note to myself for pushing config
  # git config url."git@github.com:".pushInsteadOf "https://github.com/"
  shellHook = ''
    lefthook install
    git fetch
    git status --short --branch
  '';
}
