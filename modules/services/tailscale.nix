_: {
  flake.nixosModules.tailscale = {
    pkgs,
    config,
    ...
  }: {
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
        "--accept-dns=false"   # Don't let Tailscale override your dnsmasq
        "--accept-routes=true"
      ];
    };

    # Persist the Tailscale state across reboots
    environment.persistence = {
      "/persistent".directories = ["/var/lib/tailscale"];
    };

    networking.firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [config.services.tailscale.port];
    };
  };
}
