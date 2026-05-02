# Grafana Alloy — log shipper. Successor to promtail (which reached EOL
# in nixpkgs). Each host runs alloy reading systemd journal → forwards to
# Loki on sorbet.
_: let
  sorbetTailscaleIp = "100.120.32.9";

  # Alloy config language is HCL-like. Same logical pipeline as promtail:
  # journal source → relabel rules → loki.write endpoint.
  mkAlloyConfig = {
    lokiUrl,
    hostname,
  }: pkgs:
    pkgs.writeText "alloy-config.alloy" ''
      // Loki write target — receives all log streams.
      loki.write "default" {
        endpoint {
          url = "${lokiUrl}/loki/api/v1/push"
        }
        // Backoff so a downed loki doesn't pile up requests in memory.
        external_labels = {
          host = "${hostname}",
        }
      }

      // Relabel: lift useful journal fields to top-level labels so
      // queries like {unit="caddy.service"} work in Loki.
      loki.relabel "journal" {
        forward_to = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["__journal__hostname"]
          target_label  = "nodename"
        }
        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }
      }

      // Source: read everything from the journal.
      loki.source.journal "all" {
        forward_to    = [loki.write.default.receiver]
        relabel_rules = loki.relabel.journal.rules
        max_age       = "12h"
        labels        = {
          job  = "systemd-journal",
          host = "${hostname}",
        }
      }
    '';

  mkAlloyModule = {
    lokiUrl,
    hostname,
  }: {pkgs, ...}: {
    services.alloy = {
      enable = true;
      configPath = mkAlloyConfig {inherit lokiUrl hostname;} pkgs;
    };

    # Grant the upstream-managed alloy user access to the journal.
    # Done via group membership rather than redefining users.users.alloy
    # (which would conflict with the module's own user creation).
    systemd.services.alloy.serviceConfig.SupplementaryGroups = ["systemd-journal"];
  };
in {
  flake.nixosModules.alloy = mkAlloyModule {
    lokiUrl = "http://127.0.0.1:3100";
    hostname = "sorbet";
  };

  flake.eclairNixosModules.alloy = mkAlloyModule {
    lokiUrl = "http://${sorbetTailscaleIp}:3100";
    hostname = "eclair";
  };
}
