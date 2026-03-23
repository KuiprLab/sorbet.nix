{ self, inputs, ... }:
let

  # Shared nixpkgs config
  nixpkgsConfig = {
    allowUnfree = true;
    allowBroken = false;
    allowUnsupportedSystem = false;
  };

  # Overlays
  overlays = [
  ];
in
{
  flake.nixosConfigurations.sorbet = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.sorbetConfiguration
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
          ];
        };
      }
    ];
  };

}
