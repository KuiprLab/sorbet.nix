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

      nixpkgs.overlays = lib.mkAfter [
        (_: prev: {
          caddy = prev.caddy.override (old: {
            buildGoModule = args:
              prev.buildGoModule (args
                // {
                  overrideModAttrs = _: {
                    preBuild = ''
                      go get github.com/caddy-dns/bunny
                    '';
                  };
                  postInstall =
                    (args.postInstall or "")
                    + ''
                      ${prev.xcaddy}/bin/xcaddy build \
                        --with github.com/caddy-dns/cloudflare \
                        --output $out/bin/caddy
                    '';
                });
          });
        })
      ];

      services.caddy = {
        enable = true;
        globalConfig = ''
          acme_dns bunny {env.BUNNY_API_KEY}
        '';
        virtualHosts = lib.mapAttrs (_: extraConfig: {inherit extraConfig;}) virtualHosts;
      };

      systemd.services.caddy.serviceConfig.EnvironmentFile =
        config.sops.secrets."caddy/cloudflare_api_token".path;
    };
}
