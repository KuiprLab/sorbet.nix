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
    {
      pkgs,
      config,
      ...
    }: {
      networking.firewall.allowedTCPPorts = [80 443];

      sops.secrets."caddy/cloudflare_api_token" = {
        sopsFile = ./caddy-secrets;
        format = "binary";
        key = "";
        owner = "caddy";
      };

      services.caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
          plugins = ["github.com/caddy-dns/bunny@v1.2.0"];
          hash = "sha256-SbhLINpMjh9YJ5J9FC6gqa+Bz1Yh41X+53qTHgJyOOY=";
        };
        globalConfig = ''
          acme_dns bunny {
              api_key {env.BUNNY_API_KEY}
              zone kuipr.de
          }
        '';
        virtualHosts = lib.mapAttrs (_: extraConfig: {inherit extraConfig;}) virtualHosts;
      };

      systemd.services.caddy.serviceConfig.EnvironmentFile =
        config.sops.secrets."caddy/cloudflare_api_token".path;
    };
}
