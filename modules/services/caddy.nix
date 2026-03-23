_: {
  flake.nixosModules.caddy = {pkgs, ...}: {
    services.caddy = {
      enable = true;
    };
  };
}
