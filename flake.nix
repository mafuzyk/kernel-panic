{
  description = "KERNEL PANIC — neon arena shooter about keeping one stubborn process alive";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        kernel-panic = pkgs.callPackage ./packaging/nix/package.nix {
          src = self;
          version = "3.1.0";
        };
        default = kernel-panic;
      });

      apps = forAllSystems (pkgs: rec {
        kernel-panic = {
          type = "app";
          program = "${self.packages.${pkgs.system}.kernel-panic}/bin/kernel-panic";
        };
        default = kernel-panic;
      });

      # `nix develop` dá o motor e as ferramentas usadas para desenvolver o
      # jogo, sem instalar nada na máquina.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.godot_4_7
            pkgs.godot_4_7-export-templates-bin
            pkgs.python3
          ];
          shellHook = ''
            export HOME=''${HOME:-$PWD/.nix-home}
            mkdir -p "$HOME/.local/share/godot/export_templates"
            ln -sfn ${pkgs.godot_4_7-export-templates-bin}/share/godot/export_templates/* \
              "$HOME/.local/share/godot/export_templates/" 2>/dev/null || true
            echo "KERNEL PANIC // godot4 --path . -- --autotest"
          '';
        };
      });
    };
}
