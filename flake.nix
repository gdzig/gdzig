{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    zig.url = "github:mitchellh/zig-overlay";
    zig.inputs.nixpkgs.follows = "nixpkgs";
    zls.url = "github:zigtools/zls";
    zls.inputs.nixpkgs.follows = "nixpkgs";
    zls.inputs.zig-overlay.follows = "zig";
  };

  outputs = {
    self,
    nixpkgs,
    zig,
    zls,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
      });
  in {
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
        zigPinned = zig.packages.${system}."0.14.1";
        zlsPinned = zls.packages.${system}.zls.overrideAttrs (prev: {
          buildInputs = [zigPinned];
        });
        inherit (pkgs) lib stdenv;
      in {
        default = pkgs.mkShell {
          buildInputs =
            [
              pkgs.lldb
              zigPinned
              zlsPinned
            ]
            ++ lib.optionals stdenv.isLinux [
              pkgs.godot
            ];
        };
      }
    );
  };
}
