# Music services flake-parts module
# Imports: caddy virtual hosts, gatus endpoints, and the NixOS music module
# The NixOS module is split across _*.nix files (ignored by import-tree)
{inputs, ...}: {
  flake = {
    caddyVirtualHosts = {
      "music.int.kuipr.de" = ''
        reverse_proxy localhost:4533 {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      '';
      "music.ext.kuipr.de" = ''
        reverse_proxy localhost:4533 {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      '';
      "tagger.int.kuipr.de" = ''
        reverse_proxy localhost:8099 {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      '';

      "musai.int.kuipr.de" = ''
        reverse_proxy localhost:8000 {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      '';
    };

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
      {
        name = "Audiomuse AI";
        url = "https://musai.int.kuipr.de";
        conditions = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 2h"
        ];
        alerts = [{type = "discord";}];
      }
    ];

    nixosModules.music = {pkgs, ...}: let
      homeDir = "/home/daniel";
      musicFolder = "${homeDir}/music";
      inboxFolder = "${homeDir}/music-inbox";
      importLog = "${homeDir}/.beets/import.log";
      pluginDir = "/var/lib/navidrome/plugins";
      musicTaggerStateDir = "/var/lib/music-tagger";

      musicTagger = pkgs.callPackage ../../../pkgs/music-tagger {
        inherit (pkgs) playwright-driver;
        src = inputs.music-tagger;
      };

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

        (mkPlugin {
          name = "audiomuseai";
          url = "https://github.com/NeptuneHub/AudioMuse-AI-NV-plugin/releases/download/v7/audiomuseai.ndp";
          hash = "sha256-+rfCg8PrnfDhB75Q/HNE1lfFG8n0sBBB+y/cOMvaQ/g=";
        })
      ];
    in {
      # Make shared vars available to all imported sub-modules
      _module.args = {
        inherit
          homeDir
          musicFolder
          inboxFolder
          importLog
          pluginDir
          musicTaggerStateDir
          musicTagger
          plugins
          ;
      };

      imports = [
        ./_users.nix
        ./_navidrome.nix
        ./_gdrive-sync.nix
        ./_beets.nix
        ./_samba.nix
        ./_audiomuseai.nix
      ];

      services.audiomuse.enable = true;
    };
  };
}
