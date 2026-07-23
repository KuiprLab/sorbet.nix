{
  lib,
  config,
  ...
}: {
  options.flake.caddyVirtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        extraConfig = lib.mkOption {
          type = lib.types.str;
          description = ''
            Caddyfile site block body. Injected as a vhost extraConfig.
          '';
        };
        name = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Human-readable service name for the auto-generated index page.
            Falls back to the hostname when null.
          '';
        };
      };
    });
    default = {};
    description = ''
      Caddy virtual host configurations contributed by service modules.
      Keys are hostnames, values are submodules with extraConfig and
      optional name (shown on the index page at home.int.kuipr.de).
    '';
  };

  config.flake = {
    # Placeholder entries for auto-generated vhosts (overridden by NixOS module
    # where pkgs is available). Keeps the hostname registered so gatus/caddy
    # can reference it.
    caddyVirtualHosts = {
      "home.int.kuipr.de" = {
        extraConfig = ''
          templates
          file_server
        '';
        name = "sorbet";
      };
    };

    gatusEndpoints = [
      {
        name = "Sorbet Index";
        group = "Infrastructure";
        url = "https://home.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 168h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.caddy = let
      virtualHosts = config.flake.caddyVirtualHosts;
      hostnames = lib.sort (a: b: a < b) (lib.attrNames virtualHosts);
    in
      {
        pkgs,
        config,
        ...
      }: let
        indexHtml = pkgs.writeText "index.html" ''
          <!DOCTYPE html>
          <html lang="en" data-theme="dark">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>sorbet</title>
            <style>
              *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
              :root {
                --bg: #0f1117;
                --surface: #1a1d27;
                --border: #2a2d3a;
                --text: #e1e4ed;
                --text-dim: #888ba0;
                --accent: #7c8aff;
                --accent-hover: #9ba6ff;
                --radius: 10px;
              }
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: var(--bg);
                color: var(--text);
                min-height: 100vh;
                display: flex;
                flex-direction: column;
                align-items: center;
                padding: 3rem 1rem;
              }
              h1 {
                font-size: 1.5rem;
                font-weight: 600;
                letter-spacing: -0.02em;
                margin-bottom: 2rem;
                color: var(--accent);
              }
              .grid {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
                gap: 0.75rem;
                width: 100%;
                max-width: 900px;
              }
              a {
                display: flex;
                align-items: center;
                gap: 0.75rem;
                padding: 0.875rem 1rem;
                background: var(--surface);
                border: 1px solid var(--border);
                border-radius: var(--radius);
                text-decoration: none;
                color: var(--text);
                font-size: 0.9rem;
                transition: border-color 0.15s, background 0.15s;
              }
              a:hover {
                border-color: var(--accent);
                background: #222639;
              }
              .host {
                font-weight: 500;
              }
              .scheme {
                color: var(--text-dim);
                font-size: 0.8rem;
              }
              .domain {
                color: var(--text-dim);
                font-size: 0.8rem;
                margin-left: auto;
              }
              footer {
                margin-top: 3rem;
                font-size: 0.8rem;
                color: var(--text-dim);
              }
            </style>
          </head>
          <body>
            <h1>sorbet</h1>
            <div class="grid">
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (host: v: let
              displayName =
                if v.name != null
                then v.name
                else host;
              hasDomain = v.name != null;
            in ''
              <a href="https://${host}">
                <span class="scheme">https://</span>
                <span class="host">${displayName}</span>
                ${
                if hasDomain
                then "<span class='domain'>${host}</span>"
                else ""
              }
              </a>
            '')
            virtualHosts)}
            </div>
            <footer>generated at build time</footer>
          </body>
          </html>
        '';
      in {
        networking.firewall.allowedTCPPorts = [80 443 3001];

        sops.secrets."caddy/bunny_api_key" = {
          sopsFile = ../../secrets/sorbet/caddy;
          format = "binary";
          key = "";
          owner = "caddy";
        };

        services.caddy = {
          enable = true;
          package = pkgs.caddy.withPlugins {
            plugins = ["github.com/caddy-dns/bunny@v1.2.0"];
            hash = "sha256-zKqfJW6ScRsrYTwUTyGkj46G5//RwHITd+a/mDj/6FQ=";
          };
          globalConfig = ''
            acme_dns bunny {env.BUNNY_API_KEY}
          '';
          virtualHosts =
            lib.mapAttrs (_: v: {extraConfig = v.extraConfig;}) virtualHosts
            // {
              "home.int.kuipr.de" = {
                extraConfig = ''
                  root * ${indexHtml}
                  file_server
                '';
              };
            };
        };

        systemd.services.caddy.serviceConfig.EnvironmentFile =
          config.sops.secrets."caddy/bunny_api_key".path;
      };
  };
}
