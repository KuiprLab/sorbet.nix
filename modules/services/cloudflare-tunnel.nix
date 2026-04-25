{lib, ...}: {
  flake.nixosModules.cloudflareTunnel = {
    config,
    lib,
    ...
  }: {
    options.services.cloudflared.tunnelId = lib.mkOption {
      type = lib.types.str;
      description = ''
        Cloudflare Tunnel UUID. Must match the tunnel ID in the credentials JSON.
        Create the tunnel with: cloudflared tunnel create ext-kuipr-de
        Then set this to the UUID printed by that command.
      '';
      example = "00000000-0000-0000-0000-000000000000";
    };

    config = {
      sops.secrets."cloudflare-tunnel/credentials" = {
        sopsFile = ../../secrets/cloudflare-tunnel-secrets;
        format = "binary";
        key = "";
        # systemd LoadCredential reads this as root before dropping privileges
        owner = "root";
      };

      services.cloudflared = {
        enable = true;
        tunnels = {
          ${config.services.cloudflared.tunnelId} = {
            credentialsFile = config.sops.secrets."cloudflare-tunnel/credentials".path;
            # Route all *.ext.kuipr.de to Caddy.
            # Caddy owns TLS (BunnyCDN DNS-01 ACME) and all vhost routing.
            ingress = {
              "*.ext.kuipr.de" = {
                service = "https://localhost:443";
                originRequest = {
                  noTLSVerify = true;
                };
              };
            };
            default = "http_status:404";
          };
        };
      };
    };
  };
}
