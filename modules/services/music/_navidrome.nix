# Navidrome service configuration, plugins, and tmpfiles
{
  lib,
  pkgs,
  config,
  musicFolder,
  pluginDir,
  homeDir,
  inboxFolder,
  plugins,
  ...
}: {
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
      "Backup.Schedule" = "0 0 * * *"; # daily at midnight
      "CoverArtPriority" = "embedded, cover.*, folder.*, external";
      "ArtistArtPriority" = "artist.*, album/artist.*, external";
      "Scanner.PurgeMissing" = "always";
    };
  };
}
