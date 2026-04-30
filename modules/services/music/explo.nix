_: {
  flake = {
    caddyVirtualHosts = {
      "explo.int.kuipr.de" = ''
        reverse_proxy 127.0.0.1:9765
      '';
    };

    nixosModules.soulbeet = {config, ...}: {
      sops.secrets = {
        "explo" = {
          sopsFile = ../../../secrets/sorbet/explo.env;
          format = "dotenv";
          key = "";
        };
      };

      virtualisation.oci-containers = {
        containers = {
          explo = {
            volumes = [
              "${config.sops.secrets."explo".path}:/opt/explo/.env"
              "/home/daniel/music/explo:/data/"
              "/home/daniel/slskd-downloads:/slskd/"
            ];
            environment.TZ = "UTC";
            image = "ghcr.io/lumepart/explo:latest";
            ports = [
            ];
            environment = {
              "WEEKLY_EXPLORATION_SCHEDULE" = "15 00 * * 2"; # Runs weekly, every Tuesday 15 minutes past midnight

              "WEEKLY_JAMS_SCHEDULE" = "30 00 * * 1"; # Runs weekly, every Monday 30 minutes past midnight
              "WEEKLY_JAMS_FLAGS" = "--playlist=weekly-jams --download-mode=skip"; # Get tracks from weekly-jams, and only add tracks that are found locally to playlist

              "DAILY_JAMS_SCHEDULE" = "15 01 * * *"; # Runs daily, every day 15 minutes past 1PM
              "DAILY_JAMS_FLAGS" = "--playlist=daily-jams --download-mode=skip"; # Get tracks from daily-jams, and only add tracks that are found locally to playlist
              "EXECUTE_ON_START" = "true";
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
