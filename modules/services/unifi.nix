_: {
  flake.nixosModules.unifi = _: {
    services.unifi = {
      enable = true;
      openFirewall = true;
    };
  };
}
