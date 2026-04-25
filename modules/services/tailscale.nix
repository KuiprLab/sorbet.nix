_: {
  flake.nixosModules.tailscale = {
    config,
    pkgs,
    lib,
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
        "--accept-dns=false"
        "--accept-routes=true"
        "--advertise-routes=192.168.0.0/24"
      ];
    };

    systemd.services.tailscale-funnel = {
      description = "Tailscale funnel port 443 to Caddy";
      after = ["tailscaled.service" "tailscale-autoconnect.service" "network-online.target"];
      wants = ["tailscaled.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale funnel --bg 443";
        ExecStop = "${pkgs.tailscale}/bin/tailscale funnel off";
      };
    };

    networking.firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [config.services.tailscale.port];
    };
  };
}
