# Navidrome service, plugins, tmpfiles, and music-tagger
_: {
  flake.nixosModules.navidrome = {
    pkgs,
    lib,
    ...
  }: let
    homeDir = "/home/daniel";
    musicFolder = "/media/data/music";
    inboxFolder = "${homeDir}/music-inbox";
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
      (mkPlugin {
        name = "audiomuseai";
        url = "https://github.com/NeptuneHub/AudioMuse-AI-NV-plugin/releases/download/v7/audiomuseai.ndp";
        hash = "sha256-+rfCg8PrnfDhB75Q/HNE1lfFG8n0sBBB+y/cOMvaQ/g=";
      })
    ];
  in {
    systemd = {
      services.navidrome.serviceConfig = {
        BindReadOnlyPaths = [musicFolder];
        ProtectHome = lib.mkForce false;
      };

      tmpfiles.rules =
        [
          "d ${pluginDir} 0750 navidrome navidrome - -"
          "d ${homeDir}/backups 0750 daniel daniel - -"
          "d ${musicFolder} 0775 daniel music - -"
          "d ${inboxFolder} 0775 daniel daniel - -"
        ]
        ++ map (p: "L+ ${pluginDir}/${p.name}.ndp - - - - ${p.pkg}") plugins;
    };

    services.navidrome = {
      enable = true;
      settings = {
        MusicFolder = musicFolder;
        "Plugins.Enabled" = true;
        "Backup.Path" = "/var/lib/navidrome/backups";
        "Backup.Count" = 7;
        "Backup.Schedule" = "0 0 * * *";
        "CoverArtPriority" = "embedded, cover.*, folder.*, external";
        "ArtistArtPriority" = "artist.*, album/artist.*, external";
        "Scanner.PurgeMissing" = "always";
        "EnableSharing" = true;
        "AutoImportPlaylists" = true;
        "Subsonic.DefaultReportRealPath" = true;
      };
    };
  };
}
