_: {
  # https://nixos.wiki/wiki/Home_Assistant#NixOS_Module
  flake.nixosModules.homeassistant = _: {
    networking.firewall = {
      allowedTCPPorts = [8123];

      allowedTCPPortRanges = [
        {
          from = 100;
          to = 65535;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 100;
          to = 65535;
        }
      ];
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.homeassistant = {
        volumes = ["home-assistant:/config"];
        environment.TZ = "Europe/Berlin";
        image = "ghcr.io/home-assistant/home-assistant:stable"; # Warning: if the tag does not change, the image will not be updated
        extraOptions = [
          "--network=host"
          # "--device=/dev/ttyACM0:/dev/ttyACM0" # Example, change this to match your own hardware
        ];
      };
    };
  };
}
