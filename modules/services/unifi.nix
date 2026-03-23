_: {
  flake.nixosModules.unifi = {pkgs, ...}: {
    services.unifi = {
      enable = true;
      openFirewall = true;
      package = pkgs.unifi;
      mongodbPackage = pkgs.mongodb;
    };
  };
}
