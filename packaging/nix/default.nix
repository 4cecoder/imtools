# Standalone Nix expression for imtools
# Usage:
#   nix-build default.nix
#   nix-env -if default.nix
#   nix-shell -p '(import ./default.nix {})'

{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation rec {
  pname = "imtools";
  version = "1.0.0";

  src = pkgs.fetchFromGitHub {
    owner = "4cecoder";
    repo = "imtools";
    rev = "v${version}";
    sha256 = "REPLACE_WITH_ACTUAL_SHA256";
  };

  nativeBuildInputs = [ pkgs.zig ];

  dontConfigure = true;
  dontInstall = true;

  buildPhase = ''
    runHook preBuild

    export XDG_CACHE_HOME="$TMPDIR/zig-cache"
    mkdir -p "$XDG_CACHE_HOME"

    zig build -Doptimize=ReleaseSafe --prefix $out

    runHook postBuild
  '';

  meta = with pkgs.lib; {
    description = "Fast image manipulation CLI tool written in Zig";
    homepage = "https://github.com/4cecoder/imtools";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "imtools";
  };
}
