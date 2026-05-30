_: {
  flake = {
    caddyVirtualHosts = {
      "beets.int.kuipr.de" = ''
        reverse_proxy localhost:7290
      '';
    };

    nixosModules.beetroot = {config, ...}: {
      sops.secrets = {
        "beetroot" = {
          sopsFile = ../../../secrets/sorbet/beetroot.yaml;
          format = "yml";
          key = "";
        };
      };

      services.beetroot-v2 = {
        enable = true;
        port = 7290;
        configFile = config.sops.secrets."beetroot".path;
      };
    };
  };
}
