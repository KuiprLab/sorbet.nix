_: {
  flake = {
    caddyVirtualHosts."homeassistant.lan" = ''
      reverse_proxy localhost:8123
      tls internal
    '';

    gatusEndpoints = [
      {
        name = "Home Assistant";
        url = "https://homeassistant.lan";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 2h"
        ];
      }
    ];

    # https://nixos.wiki/wiki/Home_Assistant#NixOS_Module
    nixosModules.homeassistant = _: {
      virtualisation.oci-containers = {
        backend = "podman";
        containers.homeassistant = {
          volumes = ["home-assistant:/config"];
          environment.TZ = "Europe/Berlin";
          image = "ghcr.io/home-assistant/home-assistant:stable"; # Warning: if the tag does not change, the image will not be updated
          labels = {
            "io.containers.autoupdate" = "registry";
          };
          extraOptions = [
            "--network=host"
          ];
        };
      };
    };
  };
}
