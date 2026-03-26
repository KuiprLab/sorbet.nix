_: {
  flake = {
    caddyVirtualHosts."musicassistant.internal.kuipr.de" = ''
      reverse_proxy localhost:8095
    '';

    gatusEndpoints = [
      {
        name = "Music Assistant";
        url = "https://musicassistant.internal.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 2h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.musicassistant = _: {
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
