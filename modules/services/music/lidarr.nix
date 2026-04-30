_: {
  flake = {
    caddyVirtualHosts = {
      "lidarr.int.kuipr.de" = ''
        reverse_proxy 127.0.0.1:8686
      '';
    };

    nixosModules.lidarr = {pkgs, ...}: let
      scriptsInit = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/scripts_init.bash";
        hash = "sha256-jGmtzdr0NZWMEy7m2CRx0+AaR9SxYdywsEAVi0iTJTA=";
      };

      customContInitDir = pkgs.runCommand "lidarr-custom-cont-init" {} ''
        mkdir -p $out
        cp ${scriptsInit} $out/scripts_init.bash
        chmod +x $out/scripts_init.bash
      '';

      customServicesDir = pkgs.runCommand "lidarr-custom-services" {} ''
        mkdir -p $out
      '';
    in {
      sops.secrets = {
      };

      virtualisation.oci-containers = {
        containers = {
          lidarr = {
            user = "1000:100";
            volumes = [
              "/home/daniel/lidarr:/config"

              "/home/daniel/music:/music" # optional
              "/home/daniel/slskd-downloads:/downloads" # optional
              "${customContInitDir}:/custom-cont-init.d:ro"
              "${customServicesDir}:/custom-services.d:ro"
            ];
            environment.TZ = "Europe/Berlin";
            image = "lscr.io/linuxserver/lidarr:latest";
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
