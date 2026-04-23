{inputs, ...}: {
  flake = {
    caddyVirtualHosts."music.int.kuipr.de" = ''
      reverse_proxy localhost:4533 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
      }
    '';

    caddyVirtualHosts."tagger.int.kuipr.de" = ''
      reverse_proxy localhost:8099 {
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

      musicTagger = pkgs.callPackage ../../pkgs/music-tagger {
        playwright-driver = pkgs.playwright-driver;
        src = inputs.music-tagger;
      };
      musicTaggerStateDir = "/var/lib/music-tagger";

      musicFolder = "${homeDir}/music";
      inboxFolder = "${homeDir}/music-inbox";

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
        music-tagger = {
          extraGroups = ["music"];
          isSystemUser = true;
          group = "music-tagger";
        };
      };

      users.groups.music-tagger = {};

      systemd = {
        services = {
          navidrome.serviceConfig = {
            BindReadOnlyPaths = [musicFolder];
            ProtectHome = lib.mkForce false;
          };

          music-tagger = {
            description = "NaviCura music tagger web UI";
            after = ["network.target"];
            wantedBy = ["multi-user.target"];
            serviceConfig = {
              Type = "simple";
              User = "music-tagger";
              Group = "music-tagger";
              # StateDirectory creates /var/lib/music-tagger and makes it
              # writable even under ProtectSystem=strict
              StateDirectory = "music-tagger";
              WorkingDirectory = musicTaggerStateDir;
              ExecStart = "${pkgs.writeShellScript "music-tagger-start" ''
                # Load secrets (may contain DB_PATH, MEDIA_ROOT, etc.)
                set -a
                source ${config.sops.secrets."music-tagger/env".path}
                set +a
                # These always win over anything in the secrets file
                export DB_PATH="${musicTaggerStateDir}/library.db"
                export MEDIA_ROOT="${musicFolder}"
                export FLASK_ENV=production
                export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
                exec ${musicTagger}/bin/music-tagger
              ''}";
              Environment = ["HOME=${musicTaggerStateDir}"];
              # Hardening — music-tagger needs write access to tag files in place
              ReadWritePaths = [musicFolder musicTaggerStateDir];
              ProtectHome = lib.mkForce false;
              ProtectSystem = "strict";
              PrivateTmp = true;
              NoNewPrivileges = true;
              Restart = "on-failure";
              RestartSec = "5s";
            };
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
            "d ${inboxFolder} 0775 daniel daniel - -"
          ]
          ++ map (p: "L+ ${pluginDir}/${p.name}.ndp - - - - ${p.pkg}") plugins;

        # Watch inbox and auto-import via beets
        user = {
          timers.beets-maintenance = {
            description = "Weekly beets library maintenance";
            timerConfig = {
              OnCalendar = "weekly";
              Persistent = true;
            };
            wantedBy = ["default.target"];
          };

          paths.beets-watch = {
            description = "Watch music inbox for new files";
            pathConfig = {
              PathModified = inboxFolder;
              MakeDirectory = true;
            };
            wantedBy = ["default.target"];
          };

          services = {
            beets-watch = {
              description = "Auto-import new music via beets";
              serviceConfig = {
                Type = "oneshot";
                TimeoutStartSec = "3h"; # don't kill the service during a long copy
                EnvironmentFile = config.sops.secrets."beets/acoustid_key".path;
                ExecStart = pkgs.writeShellScript "beets-import" ''
                  set -euo pipefail
                  echo "Waiting for inbox to settle..."
                  while true; do
                    recent=$(${pkgs.findutils}/bin/find ${inboxFolder} -mmin -1 | wc -l)
                    if [ "$recent" -eq 0 ]; then
                      echo "Inbox settled, importing..."
                      break
                    fi
                    echo "$recent file(s) still being written, waiting..."
                    sleep 30
                  done

                  ${pkgs.beets}/bin/beet -v import -q --group-albums ${inboxFolder}

                  # Remove non-audio leftover files (artwork, logs, metadata junk)
                  ${pkgs.findutils}/bin/find ${inboxFolder} \
                    -type f \
                    ! -name "*.flac" \
                    ! -name "*.mp3" \
                    ! -name "*.ogg" \
                    ! -name "*.opus" \
                    ! -name "*.m4a" \
                    ! -name "*.wav" \
                    ! -name "*.aiff" \
                    -delete

                  # Remove empty directories
                  ${pkgs.findutils}/bin/find ${inboxFolder} \
                    -mindepth 1 \
                    -type d \
                    -empty \
                    -delete
                '';
              };
            };

            beets-maintenance = {
              description = "Weekly beets library maintenance";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "beets-maintenance" ''
                  ${pkgs.beets}/bin/beet mbsync
                  ${pkgs.beets}/bin/beet fetchart -f
                  ${pkgs.beets}/bin/beet embedart
                  ${pkgs.beets}/bin/beet lyrics
                  ${pkgs.beets}/bin/beet update
                  ${pkgs.beets}/bin/beet move
                '';
              };
            };
          };
        };
      };

      # Beets config lives in home-manager (see home-manager.users.daniel below)
      environment.systemPackages = [
        pkgs.rclone
        pkgs.chromaprint
      ];

      sops.secrets = {
        "rclone/config" = {
          sopsFile = ../../secrets/rclone-secrets;
          format = "binary";
          key = "";
          owner = "navidrome";
        };

        "beets/acoustid_key" = {
          sopsFile = ../../secrets/beets-secrets;
          format = "binary";
          key = "";
          owner = "daniel";
        };

        "music-tagger/env" = {
          sopsFile = ../../secrets/music-tagger-secrets;
          format = "binary";
          key = "";
          owner = "music-tagger";
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
              quiet = false;
              timid = false;
              log = importLog;
              quiet_fallback = "asis";
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
              "chroma"
              "fetchart"
              "embedart"
              "musicbrainz"
              "mbsync"
              "lyrics"
              "bucket"
              "missing"
              "lastgenre"
            ];

            chroma.auto = true;
            acoustid.apikey = "\${ACOUSTID_APIKEY}";
            match.strong_rec_thresh = 0.2;

            embedart.auto = true;
            fetchart = {
              auto = true;
              sources = [
                "filesystem"
                "coverart"
                "itunes"
                "wikipedia"
                "fanarttv"
              ];
            };
            lyrics = {
              auto = true;
              sources = ["lrclib"];
              synced = true;
            };
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
            "Scanner.PurgeMissing" = "always";
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
            inbox = mkSambaShare inboxFolder;
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
