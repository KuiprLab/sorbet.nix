{
  lib,
  config,
  pkgs,
  ...
}: {
  options.flake.gatusEndpoints = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [];
    description = ''
      Gatus endpoint configurations contributed by service modules.
      Each entry is an attrset matching the Gatus endpoint schema.
    '';
  };

  options.flake.gatusExtraConfig = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = ''
      Extra top-level Gatus configuration (e.g. alerting, storage, web).
      Gets merged with the generated endpoints config.
    '';
  };

  # Register gatus.lan with Caddy at the flake level, same as other services
  config.flake.caddyVirtualHosts."gatus.lan" = ''
    reverse_proxy localhost:8080
    tls internal
  '';

  config.flake.nixosModules.gatus = let
    endpoints = config.flake.gatusEndpoints;
    extraConfig = config.flake.gatusExtraConfig;
    gatusConfig = extraConfig // {inherit endpoints;};
    gatusConfigFile = (pkgs.formats.yaml {}).generate "gatus.yaml" gatusConfig;
  in
    _: {
      services.gatus = {
        enable = true;
        configFile = gatusConfigFile;
      };

      networking.firewall.allowedTCPPorts = [8080];
    };
}
