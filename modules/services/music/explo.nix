_: {
  flake = {
    caddyVirtualHosts = {
      "exploy.int.kuipr.de" = ''
        reverse_proxy localhost:7288
      '';
    };

    nixosModules.explo = {config, ...}: {
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
            environment.TZ = "Europe/Berlin";
            image = "ghcr.io/lumepart/explo:dev";
            ports = [
              "7288:7288"
            ];
            environment = {
              "WEEKLY_EXPLORATION_SCHEDULE" = "15 00 * * 2"; # Runs weekly, every Tuesday 15 minutes past midnight

              "WEEKLY_JAMS_SCHEDULE" = "30 00 * * 1"; # Runs weekly, every Monday 30 minutes past midnight
              "WEEKLY_JAMS_FLAGS" = "--playlist=weekly-jams";

              # "DAILY_JAMS_SCHEDULE" = "15 01 * * *"; # Runs daily, every day 15 minutes past 1PM
              # "DAILY_JAMS_FLAGS" = "--playlist=daily-jams";
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
