# music-tagger (NaviCura) systemd service
{
  lib,
  pkgs,
  config,
  musicFolder,
  musicTagger,
  musicTaggerStateDir,
  ...
}: {
  systemd.services.music-tagger = {
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

  sops.secrets."music-tagger/env" = {
    sopsFile = ../../../secrets/music-tagger-secrets;
    format = "binary";
    key = "";
    owner = "music-tagger";
  };
}
