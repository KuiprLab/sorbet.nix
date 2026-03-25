_: {
  # https://nixos.wiki/wiki/Home_Assistant#NixOS_Module
  flake.nixosModules.musicassistant = _: {

    flake.caddyVirtualHosts."musicassistant.lan" = ''
      reverse_proxy localhost:8095
      tls internal
    '';

    virtualisation.oci-containers = {
      containers.musicassistant = {
        volumes = [ "music-assistant:/data" ];
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
}
