_: {
  flake.nixosModules.unifi = _: {
    serivces.unifi = {
      enable = true;
      openFirewall = true;
    };
  };
}
