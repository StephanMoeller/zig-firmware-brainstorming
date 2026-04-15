{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    zig
    zls
  ];

  shellHook = ''
    echo "zig: $(zig version)"
  '';
}
