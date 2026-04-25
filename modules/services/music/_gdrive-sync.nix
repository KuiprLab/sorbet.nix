# Navidrome backup sync to Google Drive via rclone
{
  pkgs,
  config,
  ...
}: {
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

  sops.secrets."rclone/config" = {
    sopsFile = ../../../secrets/rclone/sorbet;
    format = "binary";
    key = "";
    owner = "navidrome";
  };
}
