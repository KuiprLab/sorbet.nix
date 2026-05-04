# fail2ban intrusion prevention for eclair
# Monitors SSH logs and bans IPs with repeated failed authentication attempts.
_: {
  flake.eclairNixosModules.fail2ban = {pkgs, ...}: {
    services.fail2ban = {
      enable = true;

      maxretry = 5;
      bantime = "1h";
      bantime-increment = {
        enable = true;
        maxtime = "168h"; # 1 week
        factor = "2";
        multipliers = "1 2 4 8 16 32 64";
      };

      jails = {
        sshd = {
          enabled = true;
          filter = "sshd";
          port = "ssh";
          backend = "systemd";
        };
      };
    };

    # Ensure fail2ban has access to journal
    systemd.services.fail2ban.serviceConfig = {
      SupplementaryGroups = ["systemd-journal"];
    };
  };
}
