_: {
  flake.caddyVirtualHosts."musicassistant.lan" = ''
    reverse_proxy localhost:8095
    tls internal
  '';

  flake.gatusEndpoints = [
    {
      name = "Music Assistant";
      url = "https://musicassistant.lan";
      client.insecure = true;
      conditions = [
        "[STATUS] == 200"
        "[CERTIFICATE_EXPIRATION] > 2h"
      ];
    }
  ];

  flake.nixosModules.musicassistant = _: {
    virtualisation.oci-containers = {
      containers.musicassistant = {
        volumes = ["music-assistant:/data"];
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
