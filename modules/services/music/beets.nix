# Beets auto-import pipeline and home-manager configuration
_: {
  flake = {
    caddyVirtualHosts."beet.int.kuipr.de" = ''
      reverse_proxy localhost:4433 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
      }
    '';

    nixosModules.beets = {
      pkgs,
      config,
      ...
    }: let
      homeDir = "/home/daniel";
      musicFolder = "${homeDir}/music";
      inboxFolder = "${homeDir}/music-inbox";
      importLog = "${homeDir}/.beets/import.log";
    in {
      sops.secrets."beets/acoustid_key" = {
        sopsFile = ../../../secrets/sorbet/beets;
        format = "binary";
        key = "";
        owner = "daniel";
      };

      environment.systemPackages = [
        pkgs.rclone
        pkgs.chromaprint
        pkgs.inotify-tools
      ];

      services.beetroot = {
        enable = true;
        # openFirewall = true;
        frontendPort = 4433;
        musicDirectory = musicFolder;
        configDirectory = "${homeDir}/.config/beetroot";
        databasePath = "/home/daniel/.beets/library.db";
        # extraGroups = ["media"];  # Disabled - media group doesn't exist
      };

      systemd.user = {
        timers.beets-maintenance = {
          description = "Weekly beets library maintenance";
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
          };
          wantedBy = ["default.target"];
        };

        services = {
          beets-watch = {
            description = "Watch music inbox and auto-import via beets";
            wantedBy = ["default.target"];
            serviceConfig = {
              Type = "simple";
              Restart = "on-failure";
              RestartSec = "5s";
              TimeoutStartSec = "3h";
              EnvironmentFile = config.sops.secrets."beets/acoustid_key".path;
              ExecStart = pkgs.writeShellScript "beets-watch" ''
                set -euo pipefail
                mkdir -p ${inboxFolder}
                echo "Watching ${inboxFolder} for new files..."


                notify_discord() {
                  local msg="$1"
                  ${pkgs.curl}/bin/curl -s -X POST "$WEBHOOK" \
                    -H "Content-Type: application/json" \
                    -d "{\"content\": $(echo -n "$msg" | ${pkgs.jq}/bin/jq -Rs .)}" || true
                }

                ${pkgs.inotify-tools}/bin/inotifywait \
                  --monitor \
                  --recursive \
                  --event close_write,moved_to \
                  --format "%w%f" \
                  "${inboxFolder}" | while read -r _event; do
                    echo "Change detected, waiting for inbox to settle..."
                    while true; do
                      recent=$(${pkgs.findutils}/bin/find ${inboxFolder} -mmin -1 | wc -l)
                      if [ "$recent" -eq 0 ]; then
                        echo "Inbox settled, importing..."
                        break
                      fi
                      echo "$recent file(s) still being written, waiting..."
                      sleep 5
                    done

                    # Capture output, send discord on failure
                    ${pkgs.beets}/bin/beet -v import -q --group-albums ${inboxFolder} \
                        > /tmp/beets-import.log 2>&1 || true

                    if grep -q 'BAD\|checker exited with status' /tmp/beets-import.log; then
                      BAD=$(grep -A1 'BAD' /tmp/beets-import.log | head -10)
                      notify_discord "⚠️ beets import had bad files on sorbet (continued)\n\`\`\`\n$BAD\n\`\`\`"
                    fi

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
                  done
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

      home-manager.users.daniel = {
        programs.beets = {
          enable = true;
          settings = {
            directory = musicFolder;
            library = "/home/daniel/.beets/library.db";

            import = {
              move = true;
              write = true;
              autotag = true;
              quiet = false;
              timid = false;
              log = importLog;
              group_albums = true;
              quiet_fallback = "asis";
              duplicate_action = "remove";
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
              "spotify"
              "fetchart"
              "embedart"
              "musicbrainz"
              "mbsync"
              "lyrics"
              "bucket"
              "missing"
              "lastgenre"
              "badfiles"
              "duplicates"
            ];

            badfiles = {
              commands = {
                flac = "${pkgs.flac}/bin/flac --test --warnings-as-errors --silent";
                m4a = "${pkgs.ffmpeg}/bin/ffprobe -v error";
                mp3 = "${pkgs.mp3val}/bin/mp3val -si";
                ogg = "${pkgs.vorbis-tools}/bin/ogginfo";
                opus = "${pkgs.opusTools}/bin/opusinfo";
                wav = "${pkgs.ffmpeg}/bin/ffprobe -v error";
                aiff = "${pkgs.ffmpeg}/bin/ffprobe -v error";
              };
            };

            lastgenre = {
              auto = true;
              force = true;
              keep_existing = false;
            };

            musicbrainz = {
              user = "Frostplexx";
              pass = "\${MUSICBRAINZ_PASSWORD}";
              data_source_mismatch_penalty = 0.8;
            };

            spotify = {
              data_source_mismatch_penalty = 0.3;
            };

            chroma.auto = true;
            acoustid.apikey = "\${ACOUSTID_APIKEY}";
            match = {
              strong_rec_thresh = 0.10;
              max_rec = {
                missing_tracks = "strong";
                unmatched_tracks = "strong";
              };
              distance_weights.missing_tracks = 0.1;
            };

            embedart.auto = true;
            fetchart = {
              auto = true;
              lastfm_key = "\${LASTFM_APIKEY}";
              sources = [
                "filesystem"
                "coverart"
                "fanarttv"
                "lastfm"
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
    };
  };
}
