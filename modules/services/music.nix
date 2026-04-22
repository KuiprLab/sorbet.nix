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
    nixosModules.music = {pkgs, ...}: let
      music_folder = "/home/daniel/music";
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

      systemd.services.navidrome.serviceConfig.BindReadOnlyPaths = [music_folder];

      services = {
        navidrome = {
          enable = true;
          settings = {
            MusicFolder = music_folder;
          };
        };
      };

      systemd.tmpfiles.rules = [
        "d ${music_folder} 0775 daniel music - -" # group music, group-readable
      ];

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
