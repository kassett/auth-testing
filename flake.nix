{
  description = "Valiguard — Malware scanning for Tagup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs
          [
            "aarch64-darwin"
            "x86_64-darwin"
            "aarch64-linux"
            "x86_64-linux"
          ]
          (system:
            f {
              pkgs = import nixpkgs {
                inherit system;
              };
            });
    in
    {
      devShells = forAllSystems ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            (wrapHelm kubernetes-helm {
              plugins = with kubernetes-helmPlugins; [
                helm-diff
              ];
            })
            k3d
            kubectl
            helmfile
          ];
        };
      });
    };
}