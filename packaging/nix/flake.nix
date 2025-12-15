{
  description = "Fast image manipulation CLI tool written in Zig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}."0.13.0";
      in
      {
        packages = {
          default = self.packages.${system}.imtools;

          imtools = pkgs.stdenv.mkDerivation {
            pname = "imtools";
            version = "1.0.0";

            src = ./../..;

            nativeBuildInputs = [ zig ];

            dontConfigure = true;
            dontInstall = true;

            buildPhase = ''
              runHook preBuild

              # Zig needs a writable cache directory
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
          };
        };

        apps = {
          default = self.apps.${system}.imtools;
          imtools = flake-utils.lib.mkApp {
            drv = self.packages.${system}.imtools;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            zig
            pkgs.ffmpeg
            pkgs.curl
          ];

          shellHook = ''
            echo "imtools development environment"
            echo "  zig version: $(zig version)"
            echo ""
            echo "Commands:"
            echo "  zig build              # Build debug"
            echo "  zig build -Doptimize=ReleaseSafe  # Build release"
            echo "  ./zig-out/bin/imtools help"
          '';
        };
      }
    );
}
