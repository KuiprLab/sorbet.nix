_: {
  flake = {
    caddyVirtualHosts."home.int.kuipr.de" = ''
      reverse_proxy localhost:8082
    '';

    gatusEndpoints = [
      {
        name = "Homepage";
        url = "https://home.int.kuipr.de";
        group = "Misc";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 168h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.homepage = {config, ...}: {
      sops.secrets."homepage/env" = {
        sopsFile = ../../secrets/sorbet/homepage;
        format = "binary";
        key = "";
        owner = "root";
        mode = "0444";
        restartUnits = ["homepage-dashboard.service"];
      };

      environment.systemPackages = [];

      services.homepage-dashboard = {
        enable = true;
        listenPort = 8082;
        openFirewall = false;
        allowedHosts = "home.int.kuipr.de";
        environmentFiles = [config.sops.secrets."homepage/env".path];

        settings = {
          title = "Sorbet";
          startUrl = "https://home.int.kuipr.de";
          theme = "dark";
          color = "slate";
          headerStyle = "clean";
          layout = {
            Infrastructure = {
              style = "row";
              columns = 4;
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
                Grafana = {
                  description = "Logs Dashboard";
                  href = "https://grafana.int.kuipr.de";
                  icon = "grafana";
                  widget = {
                    type = "grafana";
                    version = "2";
                    url = "https://grafana.int.kuipr.de";
                  };
                };
              }

              {
                Caddy = {
                  description = "Reverse proxy";
                  href = "https://home.int.kuipr.de";
                  icon = "caddy";
                  widget = {
                    type = "caddy";
                    url = "http://localhost:2019";
                  };
                };
              }
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

              {
                Sorbet = {
                  description = "Tailscale status";
                  icon = "tailscale";
                  widget = {
                    type = "tailscale";
                    deviceid = "{{HOMEPAGE_VAR_TAILSCALE_ID}}";
                    key = "{{HOMEPAGE_VAR_TAILSCALE_KEY}}";
                  };
                };
              }

              {
                Eclair = {
                  description = "Tailscale status";
                  icon = "tailscale";
                  widget = {
                    type = "tailscale";
                    deviceid = "{{HOMEPAGE_VAR_TAILSCALE_ID}}";
                    key = "{{HOMEPAGE_VAR_TAILSCALE_KEY}}";
                  };
                };
              }
              {
                NextDNS = {
                  description = "DNS filtering";
                  href = "https://my.nextdns.io";
                  icon = "nextdns";
                  widget = {
                    type = "nextdns";
                    profile = "{{HOMEPAGE_VAR_NEXTDNS_PROFILE}}";
                    key = "{{HOMEPAGE_VAR_NEXTDNS_KEY}}";
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
                  href = "https://music.ext.kuipr.de";
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
                "SLSKD" = {
                  description = "Soulseek";
                  href = "https://slskd.int.kuipr.de/";
                  icon = "slskd";
                  widget = {
                    type = "slskd";
                    url = "https://slskd.int.kuipr.de/";
                    key = "{{HOMEPAGE_VAR_SLSKD_KEY}}";
                  };
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
      };
    };
  };
}
