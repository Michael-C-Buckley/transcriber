{pkgs}:
pkgs.writeShellApplication {
  name = "transcriber-provenance";
  runtimeInputs = [pkgs.python3];
  text = ''
    exec python3 ${./scripts/provenance.py} "$@"
  '';
}
