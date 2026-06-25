_: {
  flake = {
    caddyVirtualHosts."up.int.kuipr.de" = ''
      reverse_proxy 127.0.0.1:8091
    '';

    nixosModules.upsnap = {config, ...}: {
      sops.secrets."slskd" = {
        sopsFile = ../../../secrets/sorbet/slskd.yml;
        format = "yaml";
        key = "";
        uid = 1000;
      };

      virtualisation.oci-containers.containers.upsnap = {
        volumes = [
          "data:/app/pb_data"
        ];
        user = "1000:100";
        environment = {
          TZ = "Europe/Berlin";
          SLSKD_REMOTE_CONFIGURATION = "true";
        };
        image = "ghcr.io/seriousm4x/upsnap:latest";
        labels = {
          "io.containers.autoupdate" = "registry";
        };
        extraOptions = [
          "--dns=192.168.0.85"
          "--cap-add=NET_RAW"
        ];
      };
    };
  };
}
