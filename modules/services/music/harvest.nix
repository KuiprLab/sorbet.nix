# Harvest — replacement for soulbeet.
# - Caddy vhost: harvest.int.kuipr.de  -> 127.0.0.1:9765
# - Container image built locally via pkgs/harvest (dockerTools).
# - Reads slskd.yml for the API key (single source of truth).
# - Hands off completed downloads to /home/daniel/music-inbox where
#   beets-watch (modules/services/music/beets.nix) auto-imports them.
_: {
  flake = {
    caddyVirtualHosts."harvest.int.kuipr.de" = ''
      reverse_proxy 127.0.0.1:9765
    '';

    gatusEndpoints = [
      {
        name = "Harvest";
        url = "https://harvest.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 168h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.harvest = {
      config,
      pkgs,
      ...
    }: let
      harvest = pkgs.callPackage ../../../pkgs/harvest {};
    in {
      sops.secrets = {
        # dotenv with HARVEST_USERNAME, HARVEST_PASSWORD, HARVEST_SESSION_SECRET
        "harvest" = {
          sopsFile = ../../../secrets/sorbet/harvest;
          format = "binary";
          key = "";
          uid = 1000;
          restartUnits = ["podman-harvest.service"];
        };
      };

      # Bind harvest into gluetun's pod so it can talk to slskd via the
      # gluetun container (slskd shares its network namespace).
      systemd.services.podman-harvest = {
        requires = ["podman-gluetun.service" "podman-slskd.service"];
        after = ["podman-gluetun.service" "podman-slskd.service"];
        partOf = ["podman-compose-gluetun-root.target"];
        wantedBy = ["podman-compose-gluetun-root.target"];
      };

      virtualisation.oci-containers.containers.harvest = {
        # Use the locally built layered image; podman loads it on service start.
        imageFile = harvest.image;
        image = "harvest:${harvest.version}";

        environment = {
          TZ = "Europe/Berlin";
          # slskd shares gluetun's net ns, so reach it via gluetun's network
          # alias on the proxy network. harvest joins the same network.
          HARVEST_SLSKD_URL = "http://gluetun:5030";
          HARVEST_SLSKD_YML = "/run/secrets/slskd.yml";
          HARVEST_SLSKD_DOWNLOADS = "/downloads";
          HARVEST_TARGET_FOLDERS = "Library (auto-tag via beets)=/inbox";
        };

        environmentFiles = [config.sops.secrets."harvest".path];

        volumes = [
          # Hand-off into beets-watch
          "/home/daniel/music-inbox:/inbox"
          # Read slskd's downloads dir to track + move completed files
          "/home/daniel/slskd-downloads:/downloads"
          # Reuse slskd's API key directly
          "${config.sops.secrets."slskd".path}:/run/secrets/slskd.yml:ro"
        ];

        user = "1000:100";

        ports = [
          "127.0.0.1:9765:9765"
        ];

        extraOptions = [
          "--network=proxy"
          "--network-alias=harvest"
        ];

        labels = {
          # Locally built image; do NOT pull from any registry on update.
          "io.containers.autoupdate" = "disabled";
        };
      };
    };
  };
}
