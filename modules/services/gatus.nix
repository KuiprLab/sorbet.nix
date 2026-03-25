{
  lib,
  config,
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

  config.flake.caddyVirtualHosts."gatus.lan" = ''
    reverse_proxy localhost:8888
    tls internal
  '';

  config.flake.nixosModules.gatus = let
    endpoints = config.flake.gatusEndpoints;
    extraConfig = config.flake.gatusExtraConfig;
    gatusConfig =
      extraConfig
      // {
        inherit endpoints;
        web.port = 8888;
      };
  in
    {pkgs, ...}: {
      virtualisation.oci-containers.containers.gatus = {
        image = "ghcr.io/twin/gatus:latest";
        volumes = [
          "${(pkgs.formats.yaml {}).generate "gatus.yaml" gatusConfig}:/config/config.yaml:ro"
          "gatus-data:/data"
        ];
        ports = ["127.0.0.1:8888:8888"];
        environment.TZ = "Europe/Berlin";
        labels."io.containers.autoupdate" = "registry";
      };

      networking.firewall.allowedTCPPorts = [8888];
    };
}
