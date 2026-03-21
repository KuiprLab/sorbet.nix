{
  inputs,
  lib,
  config,
  ...
}:
let
  # Helper to collect all modules from an attrset
  collectModules = attrs: lib.attrValues (lib.filterAttrs (_n: v: v != { }) attrs);

  # Shared nixpkgs config
  nixpkgsConfig = {
    allowUnfree = true;
    allowBroken = false;
    allowUnsupportedSystem = false;
  };

  # Overlays
  overlays = [
    inputs.nixkit.overlays.default
    (_final: prev: {
      kitty = prev.kitty.overrideAttrs (_oldAttrs: {
        doCheck = false;
      });
    })
  ];
in
{
  imports = [
    inputs.flake-parts.flakeModules.modules
  ];

  # Declare the module options using flake-parts-modules
  flake = {
    modules = {
      nixos = { };
      homeManager = { };
    };

    # Darwin configuration for macbook-m4-pro
    nixosConfigurations.sorbet = inputs.nixpkgs.lib.nixosSystem {
      system = "";
      modules = [
        # Core modules
        inputs.home-manager.nixosModules.home-manager
        inputs.determinate.nixosModules.default
        # Nixpkgs configuration
        {
          nixpkgs.config = nixpkgsConfig;
          nixpkgs.overlays = overlays;
        }

        # Home Manager shared modules
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            sharedModules = [
              inputs.sops-nix.homeManagerModules.sops
            ]
            ++ collectModules config.flake.modules.homeManager;
            extraSpecialArgs = {
              inherit inputs;
              inherit (config.flake) defaults;
            };
          };
        }
      ]
      ++ collectModules config.flake.modules.darwin;
      specialArgs = {
        inherit inputs;
        inherit (config.flake) defaults;
      };
    };
  };
}
