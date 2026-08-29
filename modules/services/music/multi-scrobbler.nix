# Multi-scrobbler — monitors music activity from sources and scrobbles to clients.
# https://github.com/FoxxMD/multi-scrobbler
#
# Config: full config.json encrypted with sops at secrets/sorbet/multi-scrobbler.
# Auth sessions (spotify tokens, last.fm sessions) stored in podman volume.
_: {
  flake = {
    caddyVirtualHosts."scrobble.int.kuipr.de" = {
      extraConfig = ''
        reverse_proxy localhost:9078
      '';
      name = "Multi Scrobbler";
    };

    gatusEndpoints = [
      {
        name = "Multi-Scrobbler";
        group = "Music";
        url = "https://scrobble.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 168h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.multi-scrobbler = {config, ...}: {
      sops.secrets."multi-scrobbler/config" = {
        sopsFile = ../../../secrets/sorbet/multi-scrobbler;
        format = "binary";
        key = "";
        owner = "root";
        mode = "0444";
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/multi-scrobbler 0755 root root - -"
      ];

      virtualisation.oci-containers.containers.multi-scrobbler = {
        image = "docker.io/foxxmd/multi-scrobbler:edge";
        volumes = [
          "multi-scrobbler-config:/config"
          "${config.sops.secrets."multi-scrobbler/config".path}:/config/config.json:ro"
        ];
        environment = {
          TZ = "Europe/Berlin";
          # Used as base for OAuth redirect URIs (Spotify, Last.fm).
          BASE_URL = "https://scrobble.int.kuipr.de";
        };
        ports = ["127.0.0.1:9078:9078"];
        labels = {
          "io.containers.autoupdate" = "registry";
        };
      };
    };
  };
}
