_: {
  flake = {
    caddyVirtualHosts."searx.int.kuipr.de" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:8082
      '';
      name = "SearXNG";
    };

    gatusEndpoints = [
      {
        name = "SearXNG";
        group = "Home";
        url = "https://searx.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 168h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.searxng = {config, ...}: {
      sops.secrets."searxng.env" = {
        sopsFile = ../../secrets/sorbet/searxng.env;
        format = "dotenv";
        owner = "searx";
      };

      services.searx = {
        enable = true;
        domain = "searx.int.kuipr.de";
        environmentFile = config.sops.secrets."searxng.env".path;
        settings = {
          use_default_settings = {
            engines.keep_only = [
              "startpage"
              "duckduckgo"
              "github"
              "reddit"
              "youtube"
              "wikipedia"
            ];
          };

          search = {
            safe_search = 0;
            default_lang = "en";
            autocomplete = "duckduckgo";
            autocomplete_min = 2;
            favicon_resolver = "duckduckgo";
          };

          ui = {
            default_locale = "en";
            default_theme = "simple";
            center_alignment = true;
            hotkeys = "vim";
          };

          plugins = {
            "searx.plugins.infinite_scroll.SXNGPlugin".active = true;
          };

          server = {
            bind_address = "127.0.0.1";
            port = "8082";
            base_url = "https://searx.int.kuipr.de/";
            secret_key = "$SEARXNG_SECRET_KEY";
            limiter = false;
            public_instance = false;
          };

          categories_as_tabs = {
            general = {};
            images = {};
            music = {};
            it = {};
            science = {};
            files = {};
          };

          engines = [
            {
              name = "startpage";
              categories = ["general"];
            }
            {
              name = "duckduckgo";
              categories = ["general"];
            }
            {
              name = "github";
              categories = ["it"];
            }
            {
              name = "reddit";
              categories = ["general"];
              disabled = false;
            }
            {
              name = "youtube";
              categories = ["general"];
            }
            {
              name = "wikipedia";
              categories = ["general"];
            }
          ];
        };
      };
    };
  };
}
