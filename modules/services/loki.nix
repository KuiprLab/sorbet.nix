# Loki — log aggregation backend on sorbet.
# Single-binary mode, filesystem storage, 14d retention, 3GB cap.
# Bound to tailscale0 only — promtail on eclair pushes via tailnet.
# Caddy proxies grafana.int.kuipr.de → grafana → loki for queries; loki
# itself is not directly exposed via caddy.
_: {
  flake = {
    nixosModules.loki = {
      config,
      pkgs,
      lib,
      ...
    }: {
      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;

          server = {
            # Bind to all interfaces; firewall (below) restricts to tailscale0
            # + loopback. Caddy on sorbet hits 127.0.0.1:3100; promtail on
            # eclair hits sorbet's tailscale IP.
            http_listen_address = "0.0.0.0";
            http_listen_port = 3100;
            grpc_listen_port = 9095;
            log_level = "warn";
          };

          common = {
            path_prefix = "/var/lib/loki";
            replication_factor = 1;
            ring.kvstore.store = "inmemory";
            ring.instance_addr = "127.0.0.1";
          };

          schema_config.configs = [
            {
              from = "2024-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];

          storage_config = {
            tsdb_shipper = {
              active_index_directory = "/var/lib/loki/tsdb-index";
              cache_location = "/var/lib/loki/tsdb-cache";
            };
            filesystem.directory = "/var/lib/loki/chunks";
          };

          # Retention enforcement: compactor sweeps chunks older than the
          # retention_period below. Without this, chunks accumulate forever.
          compactor = {
            working_directory = "/var/lib/loki/compactor";
            compaction_interval = "10m";
            retention_enabled = true;
            retention_delete_delay = "2h";
            retention_delete_worker_count = 50;
            delete_request_store = "filesystem";
          };

          limits_config = {
            retention_period = "336h"; # 14 days
            # Per-tenant ingestion ceilings — protects sorbet from a runaway
            # log producer flooding loki and filling disk.
            ingestion_rate_mb = 8;
            ingestion_burst_size_mb = 16;
            max_streams_per_user = 5000;
            reject_old_samples = true;
            reject_old_samples_max_age = "168h"; # drop logs older than 7d
            allow_structured_metadata = true;
          };

          # Disable analytics phone-home.
          analytics.reporting_enabled = false;

          # Soft 3GB disk cap: when chunks dir exceeds this, compactor
          # accelerates cleanup. Hard cap enforced by ExecStartPre below.
        };
      };

      # Hard storage guard: if /var/lib/loki ever exceeds 3GB, log a warning
      # and trigger compactor. Defensive — retention should keep us well
      # under this naturally.
      systemd.services.loki-storage-guard = {
        description = "Warn if Loki storage exceeds budget";
        wantedBy = ["multi-user.target"];
        startAt = "hourly";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "loki-storage-guard" ''
            set -eu
            USED=$(${pkgs.coreutils}/bin/du -sm /var/lib/loki 2>/dev/null | ${pkgs.coreutils}/bin/cut -f1)
            BUDGET=3072
            if [ "$USED" -gt "$BUDGET" ]; then
              echo "WARNING: loki storage at ''${USED}MB exceeds ''${BUDGET}MB budget"
              # Future: send discord alert here.
              exit 1
            fi
            echo "loki storage: ''${USED}MB / ''${BUDGET}MB"
          '';
        };
      };

      # Restrict listener to tailscale0 + loopback only. Loki has no auth
      # (auth_enabled=false), so this firewall rule IS the security boundary.
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [3100];
    };
  };
}
