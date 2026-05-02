# Grafana — query UI for Loki + Prometheus.
# LAN-only via caddy (grafana.int.kuipr.de). Anonymous Viewer; admin login
# required to edit. Admin password from sops.
_: {
  flake = {
    caddyVirtualHosts."grafana.int.kuipr.de" = ''
      reverse_proxy localhost:3000
    '';

    gatusEndpoints = [
      {
        name = "Grafana";
        url = "https://grafana.int.kuipr.de/api/health";
        interval = "60s";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 168h"
          "[RESPONSE_TIME] < 1500"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.grafana = {config, ...}: {
      # Two secrets in separate sops files — admin password and the DB
      # encryption key. Both must exist before first deploy:
      #   secrets/sorbet/grafana          — raw admin password (binary)
      #   secrets/sorbet/grafana-secret   — random 32+ char key (binary)
      # Generate the secret key once with: `openssl rand -base64 32`.
      sops.secrets."grafana/admin_password" = {
        sopsFile = ../../secrets/sorbet/grafana;
        format = "binary";
        key = "";
        owner = "grafana";
        mode = "0400";
      };
      sops.secrets."grafana/secret_key" = {
        sopsFile = ../../secrets/sorbet/grafana-secret;
        format = "binary";
        key = "";
        owner = "grafana";
        mode = "0400";
      };

      services.grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = "127.0.0.1";
            http_port = 3000;
            domain = "grafana.int.kuipr.de";
            root_url = "https://grafana.int.kuipr.de/";
          };

          security = {
            admin_user = "admin";
            # Read both at runtime — keeps secrets out of the nix store.
            # $__file{} is a grafana-native escape for file-backed values.
            admin_password = "$__file{${config.sops.secrets."grafana/admin_password".path}}";
            secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
            # Cookie security; safe behind https-only caddy.
            cookie_secure = true;
            disable_initial_admin_creation = false;
          };

          # Anonymous Viewer: anyone on the LAN can see dashboards without
          # logging in. Editing/admin requires the admin login above.
          "auth.anonymous" = {
            enabled = true;
            org_role = "Viewer";
            hide_version = true;
          };

          analytics = {
            reporting_enabled = false;
            check_for_updates = false;
            check_for_plugin_updates = false;
          };

          # SQLite by default — fine for single-node, low-traffic.
        };

        # Pre-wire datasources so logging/metrics work on first boot.
        provision = {
          enable = true;
          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              uid = "prometheus";
              url = "http://127.0.0.1:9090";
              access = "proxy";
              isDefault = true;
            }
            {
              name = "Loki";
              type = "loki";
              uid = "loki";
              url = "http://127.0.0.1:3100";
              access = "proxy";
              jsonData.maxLines = 5000;
            }
          ];
        };
      };
    };
  };
}
