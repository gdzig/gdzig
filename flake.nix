{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    zig.url = "github:silversquirl/zig-flake/compat";
    zls.url = "github:zigtools/zls?ref=0.16.0";

    zig.inputs.nixpkgs.follows = "nixpkgs";
    zls.inputs.nixpkgs.follows = "nixpkgs";
    zls.inputs.zig-flake.follows = "zig";
  };

  outputs =
    {
      nixpkgs,
      zig,
      zls,
      ...
    }:
    let
      forAllSystems = f: builtins.mapAttrs f nixpkgs.legacyPackages;
    in
    {
      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.lldb
              zig.packages.${system}."0.16.0"
              zls.packages.${system}.zls
            ]
            ++ pkgs.lib.optionals (system == "x86_64-linux") [
              # Wine for cross-platform testing with -fwine
              pkgs.wineWowPackages.stable
            ];
          };
        }
      );
    };
}
