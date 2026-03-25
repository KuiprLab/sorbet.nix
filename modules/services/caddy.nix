{
  lib,
  config,
  ...
}: {
  options.flake.caddyVirtualHosts = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {};
    description = ''
      Caddy virtual host configurations contributed by service modules.
      Keys are hostnames, values are Caddyfile site block bodies (extraConfig).
    '';
  };

  config.flake.nixosModules.caddy = let
    virtualHosts = config.flake.caddyVirtualHosts;
  in
    _: {
      # caddy redirects to 443 automagically
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      services.caddy = {
        enable = true;
        virtualHosts = lib.mapAttrs (_: extraConfig: {inherit extraConfig;}) virtualHosts;
        globalConfig = ''
          pki {
            ca local {
              name "Sorbet Local CA"
              root_cn "Sorbet Local CA Root"
              intermediate_cn "Sorbet Local CA Intermediate"
              root {
                lifetime 87600h  # 10 years
              }
              intermediate {
                lifetime 43800h  # 5 years
              }
            }
          }
        '';
      };
    };
}
