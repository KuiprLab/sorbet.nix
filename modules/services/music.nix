_: {
  flake = {
    caddyVirtualHosts."music.int.kuipr.de" = ''
      reverse_proxy localhost:4533 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
      }
    '';
    gatusEndpoints = [
      {
        name = "Navidrome";
        url = "https://music.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 2h"
        ];
        alerts = [{type = "discord";}];
      }
    ];
    nixosModules.music = {
      lib,
      pkgs,
      ...
    }: let
      music_folder = "/home/daniel/music";
      pluginDir = "/var/lib/navidrome/plugins";

      mkPlugin = {
        name,
        url,
        hash,
      }: {
        pkg = pkgs.fetchurl {inherit url hash;};
        inherit name;
      };

      plugins = [
        (mkPlugin {
          name = "listenbrainz-daily-playlist";
          url = "https://github.com/kgarner7/navidrome-listenbrainz-daily-playlist/releases/download/v5.0.2/listenbrainz-daily-playlist.ndp";
          hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        })
        (mkPlugin {
          name = "discord-rich-presence";
          url = "https://github.com/navidrome/discord-rich-presence-plugin/releases/download/v1.0.0/discord-rich-presence.ndp";
          hash = "sha256-cOp9BqPc2JNZ8K0o6btKAvEu+JpoGKqcQ/AHGUE3XEI=";
        })
      ];
    in {
      users.groups = {
        music = {};
        navidrome = {};
      };
      users.users = {
        daniel = {
          extraGroups = ["music"];
          homeMode = "0711";
        };
        navidrome = {
          extraGroups = ["music"];
          isSystemUser = true;
          group = "navidrome";
        };
      };

      systemd.services.navidrome.serviceConfig = {
        BindReadOnlyPaths = [music_folder];
        ProtectHome = lib.mkForce false;
      };
      services = {
        navidrome = {
          enable = true;
          settings = {
            MusicFolder = music_folder;
            "Plugins.Enabled" = true;
          };
        };
      };

      systemd.tmpfiles.rules =
        [
          "d ${music_folder} 0775 daniel music - -"
          "d ${pluginDir} 0750 navidrome navidrome - -"
        ]
        ++ map (p: "L+ ${pluginDir}/${p.name}.ndp - - - - ${p.pkg}") plugins;

      #TODO: Create docs and add `sudo smbpasswd -a daniel` as a post deploy step
      services = {
        samba = {
          enable = true;
          settings = {
            global = {
              "workgroup" = "WORKGROUP";
              "server string" = "music-server";
              "security" = "user";
              "invalid users" = ["root"];
            };
            music = {
              "path" = music_folder;
              "browseable" = "yes";
              "read only" = "no";
              "guest ok" = "no";
              "valid users" = ["daniel"];
              "create mask" = "0644";
              "directory mask" = "0755";
            };
          };
        };

        samba-wsdd.enable = true;
      };

      networking.firewall = {
        allowedTCPPorts = [
          445
          139
        ];
        allowedUDPPorts = [
          137
          138
          5355
          3702
        ];
      };
    };
  };
}
