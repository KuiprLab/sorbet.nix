_: {
  flake = {
    caddyVirtualHosts = {
      "soulbeet.int.kuipr.de" = ''
        reverse_proxy localhost:4533
      '';

      "slskd.int.kuipr.de" = ''
        reverse_proxy localhost:5030
      '';
    };

    nixosModules.soulbeet = {
      config,
      lib,
      ...
    }: {
      sops.secrets = {
        "soulbeet" = {
          sopsFile = ../../secrets/sorbet/soulbeet;
          format = "binary";
          key = "";
        };
      };

      systemd.services.podman-slskd = {
        requires = ["podman-gluetun.service"];
        after = ["podman-gluetun.service"];
      };

      virtualisation.oci-containers = {
        containers = {
          soulbeet = {
            volumes = [
              "data:/data"
              "/home/daniel/downloads:/downloads"
              "/home/daniel/music:/music"
              "/home/daniel/.config/beets/config.yaml:/config/config.yaml:ro"
            ];
            environment.TZ = "Europe/Berlin";
            image = "docker.io/docccccc/soulbeet:latest";
            ports = [
              "4533:4533"
            ];
            labels = {
              "io.containers.autoupdate" = "registry";
            };
            environmentFiles = [config.sops.secrets."soulbeet".path];
          };

          slskd = {
            volumes = [
              "/home/daniel/downloads:/app/downloads"
              "slskd-config:/app/slskd.conf.d"
            ];
            environment = {
              TZ = "Europe/Berlin";
              SLSKD_REMOTE_CONFIGURATION = "true";
            };
            image = "docker.io/slskd/slskd:latest";
            labels = {
              "io.containers.autoupdate" = "registry";
            };
            extraOptions = [
              "--network=container:gluetun"
            ];
          };
        };
      };
    };
  };
}
