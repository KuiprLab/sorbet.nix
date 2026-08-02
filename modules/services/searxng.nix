_: {
  flake = {
    caddyVirtualHosts."searx.int.kuipr.de" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:8080
      '';
      name = "SearXNG";
    };

    gatusEndpoints = [
      {
        name = "SearXNG";
        group = "Home";
        url = "https://searx.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 168h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.searxng = {config, ...}: {
      sops.secrets."searxng.env" = {
        sopsFile = ../../secrets/sorbet/searxng.env;
        format = "dotenv";
        owner = "searx";
      };

      services.searx = {
        enable = true;
        domain = "searx.int.kuipr.de";
        environmentFile = config.sops.secrets."searxng.env".path;
        settings = {
          use_default_settings = true;
          server = {
            bind_address = "127.0.0.1";
            port = "8080";
            base_url = "https://searx.int.kuipr.de/";
            secret_key = "$SEARXNG_SECRET_KEY";
          };
        };
      };
    };
  };
}
