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

      sops.secrets."caddy/bunny_api_key" = {
        sopsFile = ../../secrets/caddy/sorbet;
        format = "binary";
        key = "";
        owner = "caddy";
      };

      services.caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
          plugins = ["github.com/caddy-dns/bunny@v1.2.0"];
          hash = "sha256-plyqmKyP631uVGWP1aV3xAKvguUYh6cYji5Yfw8fyi8=";
        };
        globalConfig = ''
          acme_dns bunny {env.BUNNY_API_KEY}
        '';
        virtualHosts = lib.mapAttrs (_: extraConfig: {inherit extraConfig;}) virtualHosts;
      };

      systemd.services.caddy.serviceConfig.EnvironmentFile =
        config.sops.secrets."caddy/bunny_api_key".path;
    };
}
