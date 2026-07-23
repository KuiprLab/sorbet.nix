# Koito — modern, themeable ListenBrainz-compatible scrobbler.
# https://koito.io
_: {
  flake = {
    caddyVirtualHosts."koito.int.kuipr.de" = ''
      reverse_proxy localhost:4110
    '';

    gatusEndpoints = [
      {
        name = "Koito";
        group = "Music";
        url = "https://koito.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 168h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.koito = _: {
      virtualisation.oci-containers.containers.koito = {
        image = "gabehf/koito:latest";
        volumes = [
          "koito-data:/etc/koito"
        ];
        environment = {
          TZ = "Europe/Berlin";
          KOITO_DEFAULT_USERNAME = "daniel";
        };
        ports = ["127.0.0.1:4110:4110"];
        labels = {
          "io.containers.autoupdate" = "registry";
        };
      };
    };
  };
}
