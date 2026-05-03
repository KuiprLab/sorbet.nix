# Prometheus — metrics on sorbet.
# 30d time-based retention + 1.5GB size cap (whichever hits first).
# Scrapes node_exporter on both hosts, haproxy on eclair, gatus locally.
_: let
  sorbetTailscaleIp = "100.120.32.9";
  eclairTailscaleIp = "100.99.168.34";
in {
  flake = {
    nixosModules.prometheus = {
      config,
      lib,
      ...
    }: {
      services.prometheus = {
        enable = true;
        port = 9090;
        # Bind to loopback only — grafana queries it via 127.0.0.1.
        listenAddress = "127.0.0.1";
        retentionTime = "30d";
        # Hard cap on tsdb size. Hits before retentionTime if logs are noisy.
        extraFlags = [
          "--storage.tsdb.retention.size=1500MB"
          "--web.enable-lifecycle"
        ];

        globalConfig = {
          scrape_interval = "30s";
          evaluation_interval = "30s";
          external_labels.cluster = "kuipr";
        };

        scrapeConfigs = [
          {
            job_name = "node";
            static_configs = [
              {
                targets = ["${sorbetTailscaleIp}:9100"];
                labels.host = "sorbet";
              }
              {
                targets = ["${eclairTailscaleIp}:9100"];
                labels.host = "eclair";
              }
            ];
          }
          {
            job_name = "haproxy";
            static_configs = [
              {
                targets = ["${eclairTailscaleIp}:8404"];
                labels.host = "eclair";
              }
            ];
            metrics_path = "/metrics";
          }
          {
            # Gatus exposes prometheus metrics natively when web.metrics=true.
            # Configured in gatus.nix gatusExtraConfig.
            job_name = "gatus";
            static_configs = [
              {
                targets = ["127.0.0.1:8888"];
                labels.host = "sorbet";
              }
            ];
            metrics_path = "/metrics";
          }
        ];
      };
    };
  };
}
