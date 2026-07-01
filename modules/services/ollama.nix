_: {
  flake = {
    caddyVirtualHosts."ollama.int.kuipr.de" = ''
      reverse_proxy 127.0.0.1:11434
    '';

    nixosModules.ollama = {pkgs, ...}: {
      services.ollama = {
        enable = true;
        # loadModels = [
        #   "gemma4:31b"
        # ];
        openFirewall = true;
        # syncModels = true;
      };
    };
  };
}
