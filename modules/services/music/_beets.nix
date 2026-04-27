# Beets auto-import pipeline and home-manager configuration
{
  pkgs,
  config,
  musicFolder,
  inboxFolder,
  importLog,
  ...
}: {
  systemd.user = {
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
              sleep 5
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

  environment.systemPackages = [
    pkgs.rclone
    pkgs.chromaprint
  ];

  sops.secrets."beets/acoustid_key" = {
    sopsFile = ../../../secrets/sorbet/beets;
    format = "binary";
    key = "";
    owner = "daniel";
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
          "mbcollection"
        ];

        badfiles = {
          check_on_import = true;
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
        };

        mbcollection = {
          auto = true;
          collection = "Frostplexx's Music";
          remove = true;
        };

        chroma.auto = true;
        acoustid.apikey = "\${ACOUSTID_APIKEY}";
        match.strong_rec_thresh = 0.2;

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
}
