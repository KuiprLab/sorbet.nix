_: {
  flake = {
    caddyVirtualHosts = {
      "soulbeet.int.kuipr.de" = ''
        reverse_proxy 127.0.0.1:9765
      '';

      "slskd.int.kuipr.de" = ''
        reverse_proxy 127.0.0.1:5030
      '';
    };

    nixosModules.soulbeet = {
      config,
      pkgs,
      ...
    }: let
      # Soulbeet beets config: just move files into the inbox as-is.
      # No tagging, organizing, or plugins — host beets-watch handles all of that.
      soulbeetBeetsConfig = pkgs.writeText "soulbeet-beets-config.yaml" ''
        directory: /inbox
        library: /data/.beets_library.db

        import:
          move: true
          write: false
          autotag: false
          quiet: true
          duplicate_action: remove

        plugins: []
      '';
    in {
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
        partOf = ["podman-compose-gluetun-root.target"];
        wantedBy = ["podman-compose-gluetun-root.target"];
      };

      virtualisation.oci-containers = {
        containers = {
          soulbeet = {
            volumes = [
              "soulbeet-data:/data"
              "/home/daniel/downloads:/downloads"
              "/home/daniel/music-inbox:/inbox"
              "${soulbeetBeetsConfig}:/config/config.yaml:ro"
            ];
            environment.TZ = "Europe/Berlin";
            image = "docker.io/docccccc/soulbeet:latest";
            ports = [
              "9765:9765"
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
