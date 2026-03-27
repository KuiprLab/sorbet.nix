_: {
  flake.nixosModules.tailscale = {config, ...}: {
    sops.secrets."tailscale/authkey" = {
      sopsFile = ../../secrets/tailscale-secrets;
      format = "binary";
      key = "";
      owner = "root";
    };

    services.tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = config.sops.secrets."tailscale/authkey".path;
      extraUpFlags = [
        "--accept-dns=false" # Don't let Tailscale override your dnsmasq
        "--accept-routes=true"
        "--advertise-routes=192.168.0.0/24"
      ];
    };

    networking.firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [config.services.tailscale.port];
    };
  };
}
