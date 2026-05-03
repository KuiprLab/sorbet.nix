_: {
  flake = {
    caddyVirtualHosts."mus.int.kuipr.de" = ''
      reverse_proxy localhost:8095
    '';

    gatusEndpoints = [
      {
        name = "Music Assistant";
        group = "Home";
        url = "https://mus.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 168h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.musicassistant = _: {
      # Enable chromecast ports
      networking.firewall = {
        allowedTCPPorts = [
          8008
          8009
          8443
        ];

        allowedUDPPorts = [
          10008
          5353
        ];
      };

      virtualisation.oci-containers = {
        containers.musicassistant = {
          volumes = ["music-assistant:/data"];
          environment.TZ = "Europe/Berlin";
          image = "ghcr.io/music-assistant/server:latest"; # Warning: if the tag does not change, the image will not be updated
          environment = {
            "LOG_LEVEL" = "info";
          };
          labels = {
            "io.containers.autoupdate" = "registry";
          };

          extraOptions = [
            "--network=host"
            "--cap-add=SYS_ADMIN"
            "--cap-add=DAC_READ_SEARCH"
          ];
        };
      };
    };
  };
}
