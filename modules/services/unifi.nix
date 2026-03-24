_: {
  flake.nixosModules.unifi = {pkgs, ...}: {
    imports = [../../pkgs/unifi-os-server-image/module.nix];

    networking.firewall = {
      allowedTCPPorts = [
        443 # HTTPS portal
        8080 # UAP device inform
        8443 # Controller HTTPS
        8843 # HTTPS portal redirect
        8880 # HTTP portal redirect
        6789 # Mobile speed test
      ];
      allowedUDPPorts = [
        3478 # STUN
        10001 # Device discovery
      ];
    };

    services.unifi-os-server = {
      enable = true;
      package = pkgs.callPackage ../../pkgs/unifi-os-server-image {
        sha256 = "sha256-IPoWR5GTiy7J1WgMEYdTxGo26qM2nO+U1c742pRo354=";
      };
      openFirewall = true;
    };
  };
}
