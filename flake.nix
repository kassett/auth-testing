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
        nixpkgs.lib.genAttrs systems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfreePredicate =
                  pkg:
                  builtins.elem (nixpkgs.lib.getName pkg) [
                    "terraform"
                  ];
              };
            };
          in
          f pkgs
        );
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages =
            with pkgs;
            [
              terraform
              (wrapHelm kubernetes-helm {
                plugins = with kubernetes-helmPlugins; [
                  helm-diff
                ];
              })
              k3d
              kubectl
              helmfile
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.docker-client
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              pkgs.docker
            ];
        };
      });
    };
}