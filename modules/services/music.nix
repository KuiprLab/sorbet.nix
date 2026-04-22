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

    caddyVirtualHosts."files.int.kuipr.de" = ''
      reverse_proxy localhost:8337
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
      inbox_folder = "/home/daniel/music-inbox";
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
          hash = "sha256-P1lB18Gjqjg6p2atn+PqQRcM0U1jSCtGWqkZDNWQ3Pk=";
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

      services.navidrome = {
        enable = true;
        settings = {
          MusicFolder = music_folder;
          "Plugins.Enabled" = true;
        };
      };

      systemd.tmpfiles.rules =
        [
          "d ${music_folder} 0775 daniel music - -"
          "d ${inbox_folder} 0775 daniel music - -"
          "d ${pluginDir} 0750 navidrome navidrome - -"
        ]
        ++ map (p: "L+ ${pluginDir}/${p.name}.ndp - - - - ${p.pkg}") plugins;

      # Beets config lives in home-manager (see homeManagerModules.music below)
      environment.systemPackages = [pkgs.chromaprint];
      home-manager.users.daniel = {
        programs.beets = {
          enable = true;
          settings = {
            directory = music_folder;
            library = "/home/daniel/.beets/library.db";

            import = {
              move = true;
              write = true;
              autotag = true;
              quiet = true;
              timid = false;
            };

            paths = {
              default = "%the{$albumartist}/%the{$album}%aunique{}/$track $title";
              singleton = "Non-Album/%the{$artist}/$title";
              comp = "Compilations/%the{$album}%aunique{}/$track $title";
            };

            plugins = [
              "fetchart"
              "embedart"
              "musicbrainz"
              "lyrics"
            ];

            musicbrainz.data_source_mismatch_penalty = 0.3; # Lower penalty = preferred
            fetchart.auto = true;
            embedart.auto = true;
            lyrics = {
              auto = true;
              sources = ["lrclib"];
            };
          };
        };
      };

      #TODO: Create docs and add `sudo smbpasswd -a daniel` as a post deploy step
      services.samba = {
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
          inbox = {
            "path" = inbox_folder;
            "browseable" = "yes";
            "read only" = "no";
            "guest ok" = "no";
            "valid users" = ["daniel"];
            "create mask" = "0644";
            "directory mask" = "0755";
          };
        };
      };

      services.samba-wsdd.enable = true;

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
