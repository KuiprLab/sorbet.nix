_: {
  flake.caddyVirtualHosts."homeassistant.lan" = ''
    reverse_proxy localhost:8123
    tls internal
  '';

  flake.gatusEndpoints = [
    {
      name = "Home Assistant";
      url = "https://homeassistant.lan";
      client.insecure = true; # since tls internal
      conditions = ["[STATUS] == 200"];
    }
  ];

  # https://nixos.wiki/wiki/Home_Assistant#NixOS_Module
  flake.nixosModules.homeassistant = _: {
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
          # "--device=/dev/ttyACM0:/dev/ttyACM0" # Example, change this to match your own hardware
        ];
      };
    };
  };
}
