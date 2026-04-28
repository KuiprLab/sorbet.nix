_: {
  flake = {
    nixosModules.musicmanager = {
      config,
      lib,
      ...
    }: {
      sops.secrets = {
        "musicmanager/bot_secrets" = {
          sopsFile = ../../secrets/sorbet/musicmanager;
          format = "binary";
          key = "";
        };
        "gluetun.env" = {
          sopsFile = ../../secrets/sorbet/gluetun.env;
          format = "dotenv";
          key = "";
          restartUnits = ["podman-gluetun.service"];
        };
      };

      systemd.services.podman-create-network-proxy = {
        description = "Create podman proxy network";
        before = ["podman-gluetun.service"];
        wantedBy = ["podman-compose-musicmanager-root.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "/bin/sh -c 'podman network exists proxy || podman network create proxy'";
        };
        path = ["/run/current-system/sw"];
      };

      systemd.services.podman-gluetun = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
        };
        requires = ["podman-create-network-proxy.service"];
        after = ["podman-create-network-proxy.service"];
        partOf = ["podman-compose-musicmanager-root.target"];
        wantedBy = ["podman-compose-musicmanager-root.target"];
      };

      systemd.services.podman-musicmanager = {
        requires = ["podman-gluetun.service"];
        after = ["podman-gluetun.service"];
        partOf = ["podman-compose-musicmanager-root.target"];
        wantedBy = ["podman-compose-musicmanager-root.target"];
      };

      systemd.targets.podman-compose-musicmanager-root = {
        unitConfig.Description = "musicmanager + gluetun pod";
        wantedBy = ["multi-user.target"];
      };

      virtualisation.oci-containers = {
        backend = "podman";
        containers = {
          musicmanager = {
            volumes = [
              "music-manager:/app"
              "/home/daniel/music-inbox:/downloads"
            ];
            environment.TZ = "Europe/Berlin";
            image = "ghcr.io/kuiprlab/music-manager:main";
            labels = {
              "io.containers.autoupdate" = "registry";
            };
            environmentFiles = [config.sops.secrets."musicmanager/bot_secrets".path];
            extraOptions = [
              "--network=container:gluetun"
            ];
          };

          "gluetun" = {
            image = "qmcgaw/gluetun";
            log-driver = "journald";
            environmentFiles = [
              "/run/secrets/gluetun.env"
            ];
            extraOptions = [
              "--cap-add=NET_ADMIN"
              "--device=/dev/net/tun:/dev/net/tun:rwm"
              "--health-cmd=[\"wget\", \"-qO-\", \"https://ipinfo.io/ip\"]"
              "--health-interval=30s"
              "--health-retries=3"
              "--health-start-period=10s"
              "--health-timeout=10s"
              "--network-alias=gluetun"
              "--network=proxy"
            ];
            ports = [
              "8081:8080"
              "5030:5030"
              "47594/tcp"
              "47594/udp"
            ];
          };
        };
      };
    };
  };
}
