{
  lib,
  config,
  ...
}: {
  options.flake = {
    gatusEndpoints = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = ''
        Gatus endpoint configurations contributed by service modules.
        Each entry is an attrset matching the Gatus endpoint schema.
      '';
    };

    gatusExtraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = ''
        Extra top-level Gatus configuration (e.g. alerting, storage, web).
        Gets merged with the generated endpoints config.
      '';
    };
  };

  config.flake = {
    gatusEndpoints = [
      {
        name = "Caddy";
        url = "https://gatus.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 2h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    caddyVirtualHosts."gatus.int.kuipr.de" = ''
      reverse_proxy localhost:8888
    '';

    gatusExtraConfig = {
      storage = {
        type = "sqlite";
        path = "/data/data.db";
      };
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
        sopsFile = ../../secrets/gatus-secrets;
        format = "binary";
        key = "";
        owner = "root";
      };

      virtualisation.oci-containers.containers.gatus = {
        image = "ghcr.io/twin/gatus:latest";
        volumes = [
          "${(pkgs.formats.yaml {}).generate "gatus.yaml" gatusConfig}:/config/config.yaml:ro"
          "gatus-data:/data"
        ];
        ports = ["127.0.0.1:8888:8888"];
        environment = {
          TZ = "Europe/Berlin";
        };
        # Inject the webhook URL from the sops secret as an env var
        environmentFiles = [config.sops.secrets."gatus/discord_webhook".path];
        labels."io.containers.autoupdate" = "registry";
      };

      # networking.firewall.allowedTCPPorts = [ 8888 ];
    };
}
