{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    zls
  ];

  shellHook = ''
    export PATH="${toString ./.}/zig-x86_64-linux-0.15.2:$PATH"
    echo "zig: $(zig version)"
    exec fish
  '';
}
