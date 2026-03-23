_: {
  flake.nixosModules.unifi = {pkgs, ...}: {
    imports = [../../../pkgs/unifi-os-server-image/module.nix];

    services.unifi-os-server = {
      enable = true;
      package = pkgs.callPackage ../../../pkgs/unifi-os-server-image {
        sha256 = "sha256-IPoWR5GTiy7J1WgMEYdTxGo26qM2nO+U1c742pRo354=";
      };
      imageTag = "uosserver:0.0.54";
      openFirewall = true;
    };
  };
}
