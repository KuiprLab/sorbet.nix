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
      config,
      ...
    }: let
      homeDir = "/home/daniel";
      musicFolder = "${homeDir}/music";
      inboxFolder = "${homeDir}/music-inbox";
      duplicatesFolder = "${homeDir}/music-duplicates";
      manualFolder = "${homeDir}/music-manual";
      importLog = "${homeDir}/.beets/import.log";
      pluginDir = "/var/lib/navidrome/plugins";

      mkPlugin = {
        name,
        url,
        hash,
      }: {
        pkg = pkgs.fetchurl {inherit url hash;};
        inherit name;
      };

      mkSambaShare = path: {
        "path" = path;
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = ["daniel"];
        "create mask" = "0644";
        "directory mask" = "0755";
      };

      # Reads the beets import log and moves:
      #   skipped (no match / user skip) → music-manual/
      #   duplicates                     → music-duplicates/
      # Each file is placed in a flat subdirectory named after its immediate parent
      # to avoid collisions between same-named files from different albums.
      sortSkippedScript = pkgs.writeShellScript "beets-sort-skipped" ''
        set -euo pipefail

        LOG="${importLog}"
        MANUAL="${manualFolder}"
        DUPES="${duplicatesFolder}"

        [ -f "$LOG" ] || exit 0

        move_path() {
          local src="$1"
          local dest_root="$2"
          local parent
          parent="$(basename "$(dirname "$src")")"
          local dest="$dest_root/$parent"
          mkdir -p "$dest"
          mv -- "$src" "$dest/" 2>/dev/null || true
        }

        while IFS= read -r line; do
          # Log lines: "<status> <path>" or "<status> <path1>; <path2>; ..."
          status="''${line%% *}"
          rest="''${line#* }"

          case "$status" in
            skip)
              # rest is a single path
              [ -e "$rest" ] && move_path "$rest" "$MANUAL"
              ;;
            duplicate)
              # rest may be "existing; candidate" — move the candidate (second path)
              IFS=';' read -ra parts <<< "$rest"
              for part in "''${parts[@]}"; do
                part="''${part# }"
                part="''${part% }"
                [ -e "$part" ] && move_path "$part" "$DUPES"
              done
              ;;
          esac
        done < "$LOG"

        # Truncate log after processing so we don't re-process on next run
        : > "$LOG"
      '';

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
        BindReadOnlyPaths = [musicFolder];
        ProtectHome = lib.mkForce false;
      };

      services.navidrome = {
        enable = true;
        settings = {
          MusicFolder = musicFolder;
          "Plugins.Enabled" = true;
          "Backup.Path" = "/var/lib/navidrome/backups";
          "Backup.Count" = 7;
          "Backup.Schedule" = "0 0 * * *"; # daily at midnight
          "CoverArtPriority" = "embedded, cover.*, folder.*, external";
          "ArtistArtPriority" = "artist.*, album/artist.*, external";
        };
      };

      systemd.tmpfiles.rules =
        [
          "d ${musicFolder} 0775 daniel music - -"
          "d ${inboxFolder} 0775 daniel music - -"
          "d ${duplicatesFolder} 0775 daniel daniel - -"
          "d ${manualFolder} 0775 daniel daniel - -"
          "d ${pluginDir} 0750 navidrome navidrome - -"
          "d ${homeDir}/backups 0750 daniel daniel - -"
        ]
        ++ map (p: "L+ ${pluginDir}/${p.name}.ndp - - - - ${p.pkg}") plugins;

      # Beets config lives in home-manager (see home-manager.users.daniel below)
      environment.systemPackages = [pkgs.rclone];

      sops.secrets."rclone/config" = {
        sopsFile = ../../secrets/rclone-secrets;
        format = "binary";
        key = "";
        owner = "navidrome";
      };

      systemd.services.navidrome-gdrive-sync = {
        description = "Sync Navidrome backups to Google Drive";
        startAt = "daily";
        serviceConfig = {
          Type = "oneshot";
          User = "navidrome";
          ExecStart = pkgs.writeShellScript "navidrome-gdrive-sync" ''
            ${pkgs.rclone}/bin/rclone sync \
              --config ${config.sops.secrets."rclone/config".path} \
              /var/lib/navidrome/backups \
              gdrive:navidrome-backups/
          '';
        };
      };

      home-manager.users.daniel = {
        programs.beets = {
          enable = true;
          settings = {
            directory = musicFolder;
            library = "${homeDir}/.beets/library.db";

            import = {
              move = true;
              write = true;
              autotag = true;
              quiet = false; # TODO: fix
              timid = false;
              singletons = true;
              log = importLog;
            };

            bucket.bucket_alpha = [
              "A-D"
              "E-L"
              "M-R"
              "S-Z"
            ];

            paths = {
              default = "%bucket{$albumartist,alpha}/$albumartist/$album/$track $title";
              singleton = "%bucket{$artist,alpha}/$artist/$album/$title";
              comp = "Compilations/$album/$track $title";
            };

            plugins = [
              "fetchart"
              "embedart"
              "musicbrainz"
              "mbsync"
              "lyrics"
              "bucket"
              "hook"
            ];

            match.strong_rec_thresh = 0.2;

            embedart.auto = true;
            fetchart = {
              auto = true;
              workers = 4;
              sources = [
                "coverart"
                "itunes"
                "wikipedia"
                "fanarttv"
              ];
            };
            lyrics = {
              auto = true;
              sources = ["lrclib"];
            };

            hook.hooks = [
              {
                # After each import session completes, sort skipped and duplicate
                # files out of the inbox into dedicated review folders.
                event = "cli_exit";
                command = "${sortSkippedScript}";
              }
            ];
          };
        };
      };

      # TODO: add `sudo smbpasswd -a daniel` as a post-deploy step
      services.samba = {
        enable = true;
        settings = {
          global = {
            "workgroup" = "WORKGROUP";
            "server string" = "music-server";
            "security" = "user";
            "invalid users" = ["root"];
          };
          music = mkSambaShare musicFolder;
          inbox = mkSambaShare inboxFolder;
          duplicates = mkSambaShare duplicatesFolder;
          manual = mkSambaShare manualFolder;
        };
      };

      # Watch inbox and auto-import via beets
      systemd.user.paths.beets-watch = {
        description = "Watch music inbox for new files";
        pathConfig = {
          PathModified = inboxFolder;
          MakeDirectory = true;
        };
        wantedBy = ["default.target"];
      };

      systemd.user.services.beets-watch = {
        description = "Auto-import new music via beets";
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
          ExecStart = "${pkgs.beets}/bin/beet import -q ${inboxFolder}";
        };
      };

      services.samba-wsdd.enable = true;

      networking.firewall = {
        allowedTCPPorts = [445 139];
        allowedUDPPorts = [137 138 5355 3702];
      };
    };
  };
}
