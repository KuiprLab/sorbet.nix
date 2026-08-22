_: {
  flake = {
    caddyVirtualHosts = {
      "beet.int.kuipr.de" = {
        extraConfig = ''
          reverse_proxy localhost:7290 {
              header_up Host {host}
              header_up X-Real-IP {remote_host}
              header_up X-Forwarded-For {remote_host}
              header_up X-Forwarded-Proto {scheme}
          }
        '';
        name = "Beetroot";
      };
    };

    nixosModules.beetroot = {config, ...}: {
      sops.secrets = {
        "beetroot" = {
          sopsFile = ../../../secrets/sorbet/beetroot.yaml;
          format = "yaml";
          key = "";
          owner = "daniel";
        };
      };

      systemd.tmpfiles.rules = [
        "d /home/daniel/beetroot 0755 daniel music - -"
      ];

      virtualisation.oci-containers.containers.beetroot-v2 = {
        image = "ghcr.io/frostplexx/beetroot:main";
        ports = ["7290:3000"];
        volumes = [
          "/home/daniel/beetroot:/data"
          "/media/data/music:/music"
          "${config.sops.secrets."beetroot".path}:/run/secrets/beetroot:ro"
        ];
        user = "1000:100";

            labels = {
              "io.containers.autoupdate" = "registry";
            };
        environment = {
          NODE_ENV = "production";
          CONFIG_PATH = "/run/secrets/beetroot";
        };
        extraOptions = [
          "--pull=newer"
        ];
      };
    };
  };
}
