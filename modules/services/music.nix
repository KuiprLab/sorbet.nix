_: {
  flake = {
    caddyVirtualHosts."music.int.kuipr.de" = ''
      reverse_proxy localhost:8096 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
      }
    '';
    gatusEndpoints = [
      {
        name = "Music Assistant";
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
      services.jellyfin = {
        enable = true;
        user = "daniel";
      };

      systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";

      systemd.tmpfiles.rules = [
        "d ${music_folder} 0755 daniel users - -"
      ];

      environment = {
        systemPackages = [pkgs.jellyfin-ffmpeg];
        sessionVariables.LIBVA_DRIVER_NAME = "iHD";
      };

      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-ocl
        ];
      };

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
