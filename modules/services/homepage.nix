_: {
  flake = {
    caddyVirtualHosts."home.int.kuipr.de" = ''
      reverse_proxy localhost:8082
    '';

    gatusEndpoints = [
      {
        name = "Homepage";
        url = "https://home.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 2h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.homepage = {config, ...}: {
      sops.secrets."homepage/env" = {
        sopsFile = ../../secrets/homepage-secrets;
        format = "binary";
        key = "";
        owner = "homepage";
        restartUnits = ["homepage-dashboard.service"];
      };

      services.homepage-dashboard = {
        enable = true;
        listenPort = 8082;
        openFirewall = false;

        settings = {
          title = "Sorbet";
          startUrl = "https://home.int.kuipr.de";
          theme = "dark";
          color = "slate";
          headerStyle = "clean";
          layout = {
            Infrastructure = {
              style = "row";
              columns = 2;
            };
            Home = {
              style = "row";
              columns = 2;
            };
            Music = {
              style = "row";
              columns = 3;
            };
          };
        };

        services = [
          {
            Infrastructure = [
              {
                UniFi = {
                  description = "Network controller";
                  href = "https://unifi.int.kuipr.de";
                  icon = "unifi";
                  widget = {
                    type = "unifi";
                    url = "https://unifi.int.kuipr.de";
                    username = "{{HOMEPAGE_VAR_UNIFI_USERNAME}}";
                    password = "{{HOMEPAGE_VAR_UNIFI_PASSWORD}}";
                    site = "default";
                  };
                };
              }
              {
                Gatus = {
                  description = "Uptime monitor";
                  href = "https://gatus.int.kuipr.de";
                  icon = "gatus";
                  widget = {
                    type = "gatus";
                    url = "http://localhost:8888";
                  };
                };
              }
            ];
          }
          {
            Home = [
              {
                "Home Assistant" = {
                  description = "Home automation";
                  href = "https://has.int.kuipr.de";
                  icon = "home-assistant";
                  widget = {
                    type = "homeassistant";
                    url = "http://localhost:8123";
                    key = "{{HOMEPAGE_VAR_HOMEASSISTANT_TOKEN}}";
                  };
                };
              }
            ];
          }
          {
            Music = [
              {
                Navidrome = {
                  description = "Music streaming";
                  href = "https://music.int.kuipr.de";
                  icon = "navidrome";
                  widget = {
                    type = "navidrome";
                    url = "http://localhost:4533";
                    user = "{{HOMEPAGE_VAR_NAVIDROME_USERNAME}}";
                    token = "{{HOMEPAGE_VAR_NAVIDROME_TOKEN}}";
                    salt = "{{HOMEPAGE_VAR_NAVIDROME_SALT}}";
                  };
                };
              }
              {
                "Music Assistant" = {
                  description = "Music player";
                  href = "https://mus.int.kuipr.de";
                  icon = "music-assistant";
                };
              }
              {
                "Music Tagger" = {
                  description = "NaviCura tagger";
                  href = "https://tagger.int.kuipr.de";
                  icon = "mdi-tag-music";
                };
              }
            ];
          }
        ];

        widgets = [
          {
            resources = {
              cpu = true;
              memory = true;
              disk = "/";
            };
          }
          {
            datetime = {
              text_size = "xl";
              format = {
                timeStyle = "short";
                dateStyle = "short";
                hourCycle = "h23";
              };
            };
          }
        ];

        environmentFiles = [config.sops.secrets."homepage/env".path];
      };
    };
  };
}
