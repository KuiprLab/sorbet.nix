_: {
  flake = {
    caddyVirtualHosts = {
      "lidarr.int.kuipr.de" = ''
        reverse_proxy 127.0.0.1:8686
      '';
    };

    nixosModules.lidarr = {pkgs, ...}: {
      sops.secrets = {
      };

      virtualisation.oci-containers = {
        containers = {
          lidarr = {
            user = "1000:100";
            volumes = [
              "/home/daniel/lidarr:/config"
              "/home/daniel/tmp:/music" # optional
              "/home/daniel/slskd-downloads:/downloads" # optional
            ];
            environment.TZ = "Europe/Berlin";
            image = "lscr.io/linuxserver/lidarr:nightly";
            ports = [
              "8686:8686"
            ];
            environment = {
            };
            labels = {
              "io.containers.autoupdate" = "registry";
            };
          };
        };
      };
    };
  };
}
