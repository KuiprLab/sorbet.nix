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

  config.flake.nixosModules.gatus = let
    endpoints = config.flake.gatusEndpoints;
    gatusConfig = {
      inherit endpoints;
    };
    gatusConfigFile = (pkgs.formats.yaml {}).generate "gatus.yaml" gatusConfig;
  in
    _: {
      services.gatus = {
        enable = true;
        configFile = gatusConfigFile;
      };

      # networking.firewall.allowedTCPPorts = [ 8080 ];

      flake.caddyVirtualHosts."gatus.lan" = ''
        reverse_proxy localhost:8080
        tls internal
      '';
    };
}
