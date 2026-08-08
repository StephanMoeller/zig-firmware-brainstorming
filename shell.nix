{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
  ];

  shellHook = ''
    export PATH="${toString ./.}/zig-x86_64-linux-0.15.2:$PATH"
    export PATH="${toString ./.}/zls-x86_64-linux-0.15.1:$PATH"
    echo "zig: $(zig version)"
    exec fish
  '';
}
