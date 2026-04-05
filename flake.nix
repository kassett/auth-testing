{
  description = "Auth Testing - evaluating various identity management systems.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems
          (system:
            f {
              pkgs = import nixpkgs {
                inherit system;
              };
              inherit system;
            });
    in
    {
      devShells = forAllSystems ({ pkgs, system }: {
        default = pkgs.mkShell {
          packages =
            with pkgs;
            [
              (wrapHelm kubernetes-helm {
                plugins = with kubernetes-helmPlugins; [
                  helm-diff
                ];
              })
              k3d
              kubectl
              helmfile
            ]
            ++ lib.optionals pkgs.stdenv.isDarwin [
              docker-client
            ]
            ++ lib.optionals pkgs.stdenv.isLinux [
              docker
            ];
        };
      });
    };
}