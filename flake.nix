{
  description = "dev env";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devenv.url = "github:ramblurr/nix-devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    clj-helpers.url = "github:outskirtslabs/clojure-nix-locker-helpers";
    clj-helpers.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{
      self,
      devenv,
      devshell,
      clj-helpers,
      ...
    }:
    let
      package =
        pkgs:
        clj-helpers.lib.mkCljLib {
          inherit pkgs;
          name = "dirs";
          version = "0.1.0";
          src = ./.;
          prepAliases = [
            "dev"
            "kaocha"
          ];
          prefetchAliases = [
            "dev:kaocha"
            "dev:shadow-cljs"
          ];
          checkCommand = ''
            clojure -Srepro -M:dev:kaocha :unit
            clojure -Srepro -M:dev:shadow-cljs compile kaocha-test
            node target/kaocha-tests.js
          '';
          gitRev = clj-helpers.lib.gitRev self;
          nativeBuildInputs = [ pkgs.nodejs ];
        };
    in
    devenv.lib.mkFlake ./. {
      inherit inputs;
      withOverlays = [
        devshell.overlays.default
        devenv.overlays.default
      ];
      packages = {
        default = package;
        # regenerates ./deps-lock.json: `nix run .#locker`
        locker = pkgs: (package pkgs).locker;
      };
      devShell =
        pkgs:
        pkgs.devshell.mkShell {
          imports = [
            devenv.capsules.base
            devenv.capsules.clojure
          ];
          commands = [
            # { package = pkgs.bazqux; }
          ];
          packages = [
            (
              if self ? packages then
                self.packages.${pkgs.system}.locker
              else
                clj-helpers.packages.${pkgs.system}.deps-lock
            )
            pkgs.dart
            pkgs.jdk25
            pkgs.nodejs
          ];
        };
    };
}
