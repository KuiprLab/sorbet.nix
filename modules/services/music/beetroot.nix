_: {
  flake = {
    caddyVirtualHosts = {
      "beet.int.kuipr.de" = ''
        reverse_proxy localhost:7290
      '';
    };

    nixosModules.beetroot = {config, ...}: {
      sops.secrets = {
        "beetroot" = {
          sopsFile = ../../../secrets/sorbet/beetroot.yaml;
          format = "yaml";
          key = "";
        };
      };

      virtualisation.oci-containers.containers.beetroot-v2 = {
        image = "ghcr.io/frostplexx/beetroot:sha-e9f9bef";
        ports = ["7290:3000"];
        volumes = [
          "/home/daniel/beetroot:/data"
          "/media/data/music/beetroot:/music"
        ];
        environment = {
          NODE_ENV = "production";
          CONFIG_PATH = config.sops.secrets."beetroot".path;
        };
      };
    };
  };
}
