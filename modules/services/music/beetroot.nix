_: {
  flake = {
    caddyVirtualHosts = {
      "beet.int.kuipr.de" = ''
        reverse_proxy localhost:7290 {
            header_up Host {host}
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}
        }
      '';
    };

    nixosModules.beetroot = {config, ...}: {
      sops.secrets = {
        "beetroot" = {
          sopsFile = ../../../secrets/sorbet/beetroot.yaml;
          format = "yaml";
          key = "";
          mode = "0444";
        };
      };

      systemd.tmpfiles.rules = [
        "d /home/daniel/beetroot 0755 root root - -"
        "d /home/daniel/music-inbox 0755 root root - -"
      ];

      virtualisation.oci-containers.containers.beetroot-v2 = {
        image = "ghcr.io/frostplexx/beetroot:main";
        ports = ["7290:3000"];
        volumes = [
          "/home/daniel/beetroot:/data"
          "/media/data/music/beetroot:/music"
          "${config.sops.secrets."beetroot".path}:/run/secrets/beetroot:ro"
          "/home/daniel/music-inbox:/inbox"
        ];
        environment = {
          NODE_ENV = "production";
          CONFIG_PATH = "/run/secrets/beetroot";
        };
        extraOptions = ["--user=root" "--pull=newer" ];
      };
    };
  };
}
