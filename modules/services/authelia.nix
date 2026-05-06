_: {
  flake = {
    caddyVirtualHosts = {
      "auth.int.kuipr.de" = ''
        reverse_proxy localhost:9091
      '';
    };
    nixosModules.authelia = {
      pkgs,
      lib,
      config,
      ...
    }: {
      sops.secrets = {
        "authelia/authelia.env" = {
          sopsFile = ../../secrets/sorbet/authelia.env;
          format = "dotenv";
          key = "";
          restartUnits = ["podman-authelia.service"];
        };

        "authelia/configuration.yml" = {
          sopsFile = ../../secrets/sorbet/configuration.yml;
          format = "yaml";
          key = "";
          restartUnits = ["podman-authelia.service"];
        };

        "authelia/authelia-users.yaml" = {
          sopsFile = ../../secrets/sorbet/users.yaml;
          key = "";
          restartUnits = ["podman-authelia.service"];
        };
      };

      # Containers
      virtualisation.oci-containers.containers = {
        "authelia" = {
          image = "docker.io/authelia/authelia:latest";
          volumes = [
            "${config.sops.secrets."authelia/configuration.yml".path}:/config/configuration.yml:ro"
            "/home/ubuntu/authelia/data:/data:rw"
            "${config.sops.secrets."authelia/authelia-users.yaml".path}:/config/users_database.yaml:rw"
          ];
          ports = [
            "9091:9091/tcp"
          ];
          environmentFiles = [
            "${config.sops.secrets."authelia/authelia.env".path}"
          ];
          labels = {
            "io.containers.autoupdate" = "registry";
          };
          log-driver = "journald";
          extraOptions = [
            "--network-alias=authelia"
            "--network=authelia_default"
            "--network=proxy"
          ];
        };

        "redis" = {
          image = "redis:alpine";
          volumes = [
            "/home/ubuntu/authelia/data/redis:/data:rw"
          ];
          labels = {};
          log-driver = "journald";
          extraOptions = [
            "--network-alias=redis"
            "--network=authelia_default"
          ];
        };
      };

      systemd.services = {
        "podman-authelia" = {
          serviceConfig = {
            Restart = lib.mkOverride 90 "always";
          };
          after = [
            "podman-network-authelia_default.service"
          ];
          requires = [
            "podman-network-authelia_default.service"
          ];
          partOf = [
            "podman-compose-authelia-root.target"
          ];
          wantedBy = [
            "podman-compose-authelia-root.target"
          ];
        };

        "podman-authelia-redis" = {
          serviceConfig = {
            Restart = lib.mkOverride 90 "always";
          };
          after = [
            "podman-network-authelia_default.service"
          ];
          requires = [
            "podman-network-authelia_default.service"
          ];
          partOf = [
            "podman-compose-authelia-root.target"
          ];
          wantedBy = [
            "podman-compose-authelia-root.target"
          ];
        };

        # Networks
        "podman-network-authelia_default" = {
          path = [pkgs.podman];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStop = "podman network rm -f authelia_default";
          };
          script = ''
            podman network inspect authelia_default || podman network create authelia_default
          '';
          partOf = ["podman-compose-authelia-root.target"];
          wantedBy = ["podman-compose-authelia-root.target"];
        };
      };

      # Root service
      # When started, this will automatically create all resources and start
      # the containers. When stopped, this will teardown all resources.
      systemd.targets."podman-compose-authelia-root" = {
        unitConfig = {
          Description = "Root target generated for Authelia.";
        };
        wantedBy = ["multi-user.target"];
      };
    };
  };
}
