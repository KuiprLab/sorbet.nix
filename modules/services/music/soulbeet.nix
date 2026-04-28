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
      # Soulbeet beets config: register files in the library without moving them.
      # Files stay wherever slskd downloaded them; host beets-watch handles tagging and organizing.
      soulbeetBeetsConfig = pkgs.writeText "soulbeet-beets-config.yaml" ''
        directory: /inbox
        library: /data/.beets_library.db

        import:
          move: true
          copy: false
          write: false
          autotag: false
          quiet: true
          duplicate_action: remove

        # Flat layout — all files land directly in /inbox with no subdirectories
        paths:
          default: $filename
          singleton: $filename
          comp: $filename

        plugins: []
      '';
    in {
      sops.secrets = {
        "soulbeet" = {
          sopsFile = ../../../secrets/sorbet/soulbeet;
          format = "binary";
          key = "";
        };

        "slskd" = {
          sopsFile = ../../../secrets/sorbet/slskd.yml;
          format = "yaml";
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
            user = "1000:1000";
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
              "${config.sops.secrets."slskd".path}:/app/slskd.yml:ro"
            ];
            # user = "1000:1000";
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

      systemd.services = {
        "podman-volume-soulbeet-data" = {
          serviceConfig.Type = "oneshot";
          script = "${pkgs.podman}/bin/podman volume create soulbeet-data || true";
          wantedBy = ["multi-user.target"];
        };
      };
    };
  };
}
