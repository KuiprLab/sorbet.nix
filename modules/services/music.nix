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
      pluginDir = "/var/lib/navidrome/plugins";
      importLog = "${homeDir}/.beets/import.log";
      homeDir = "/home/daniel";

      musicFolder = "${homeDir}/music";
      beetsFolder = "${homeDir}/music-beets";
      inboxFolder = "${beetsFolder}/inbox";
      duplicatesFolder = "${beetsFolder}/duplicates";
      manualFolder = "${beetsFolder}/manual";

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
      #   skip           (no match / user skipped)  → music-manual/
      #   duplicate-skip (already in library)        → music-duplicates/
      # Each file lands in a subdirectory named after its parent to avoid
      # collisions between same-named files from different albums.
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
          # Log line format: "<verb> <path>" or "<verb> <existing_path>; <new_path>"
          # Verbs: import, asis, skip, duplicate-skip, duplicate-keep, duplicate-replace
          status="''${line%% *}"
          rest="''${line#* }"

          case "$status" in
            skip)
              # Single path — file was skipped (no match or user skipped)
              [ -e "$rest" ] && move_path "$rest" "$MANUAL"
              ;;
            duplicate-skip)
              # Format: "existing_path; new_path" — new_path is still in inbox
              new_path="''${rest##*; }"
              [ -e "$new_path" ] && move_path "$new_path" "$DUPES"
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

      systemd = {
        services = {
          navidrome.serviceConfig = {
            BindReadOnlyPaths = [musicFolder];
            ProtectHome = lib.mkForce false;
          };

          navidrome-gdrive-sync = {
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
        };

        tmpfiles.rules =
          [
            "d ${pluginDir} 0750 navidrome navidrome - -"
            "d ${homeDir}/backups 0750 daniel daniel - -"
            "d ${musicFolder} 0775 daniel music - -"
            "d ${beetsFolder} 0775 daniel daniel - -"
            "d ${inboxFolder} 0775 daniel daniel - -"
            "d ${duplicatesFolder} 0775 daniel daniel - -"
            "d ${manualFolder} 0775 daniel daniel - -"
          ]
          ++ map (p: "L+ ${pluginDir}/${p.name}.ndp - - - - ${p.pkg}") plugins;

        # Watch inbox and auto-import via beets
        user = {
          paths.beets-watch = {
            description = "Watch music inbox for new files";
            pathConfig = {
              PathModified = inboxFolder;
              MakeDirectory = true;
            };
            wantedBy = ["default.target"];
          };

          services.beets-watch = {
            description = "Auto-import new music via beets";
            serviceConfig = {
              Type = "oneshot";
              ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
              ExecStart = "${pkgs.beets}/bin/beet import -q ${inboxFolder}";
            };
          };
        };
      };

      # Beets config lives in home-manager (see home-manager.users.daniel below)
      environment.systemPackages = [pkgs.rclone];

      sops.secrets."rclone/config" = {
        sopsFile = ../../secrets/rclone-secrets;
        format = "binary";
        key = "";
        owner = "navidrome";
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
              "missing"
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
      services = {
        navidrome = {
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

        samba = {
          enable = true;
          settings = {
            global = {
              "workgroup" = "WORKGROUP";
              "server string" = "music-server";
              "security" = "user";
              "invalid users" = ["root"];
            };
            music = mkSambaShare musicFolder;
            beets = mkSambaShare beetsFolder;
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
