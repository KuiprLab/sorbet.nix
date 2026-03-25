{
  lib,
  config,
  ...
}: {
  options.flake.gatusEndpoints = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [];
    description = ''
      Gatus endpoint configurations contributed by service modules.
      Each entry is an attrset matching the Gatus endpoint schema.
    '';
  };

  options.flake.gatusExtraConfig = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = ''
      Extra top-level Gatus configuration (e.g. alerting, storage, web).
      Gets merged with the generated endpoints config.
    '';
  };

  config.flake.caddyVirtualHosts."gatus.lan" = ''
    reverse_proxy localhost:8888
    tls internal
  '';

  config.flake.nixosModules.gatus = let
    endpoints = config.flake.gatusEndpoints;
    extraConfig = config.flake.gatusExtraConfig;
    gatusConfig =
      extraConfig
      // {
        inherit endpoints;
        web.port = 8888;
      };
  in
    {
      pkgs,
      config,
      ...
    }: {
      sops.secrets."gatus/discord_webhook" = {
        sopsFile = ./gatus-secrets;
        format = "binary";
        key = "";
        owner = "root";
      };

      virtualisation.oci-containers.containers.gatus = {
        image = "ghcr.io/twin/gatus:latest";
        volumes = [
          "${(pkgs.formats.yaml {}).generate "gatus.yaml" gatusConfig}:/config/config.yaml:ro"
          "gatus-data:/data"
          # Mount Caddy's local CA root so Gatus can verify tls internal certs
          "/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt:/etc/ssl/certs/caddy-local-ca.crt:ro"
        ];
        ports = ["127.0.0.1:8888:8888"];
        environment = {
          TZ = "Europe/Berlin";
          SSL_CERT_DIR = "/etc/ssl/certs";
        };
        # Inject the webhook URL from the sops secret as an env var
        environmentFiles = [config.sops.secrets."gatus/discord_webhook".path];
        labels."io.containers.autoupdate" = "registry";
      };

      # networking.firewall.allowedTCPPorts = [ 8888 ];

      flake.gatusExtraConfig = {
        alerting.discord = {
          webhook-url = "$DISCORD_WEBHOOK_URL";
          default-alert = {
            failure-threshold = 3;
            success-threshold = 2;
            send-on-resolved = true;
          };
        };
      };
    };
}
