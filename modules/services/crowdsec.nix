# CrowdSec security engine + firewall bouncer for eclair
# Agent detects attacks; firewall bouncer enforces bans via nftables.
# TCP-mode haproxy can't use lua/SPOE bouncer, so IP banning happens
# at the nftables layer — blocks before haproxy ever sees the connection.
#
# The bouncer API key is auto-generated on first boot via an ExecStartPre
# script on the crowdsec service — no manual steps required.
_: {
  flake.eclairNixosModules.crowdsec = {pkgs, ...}: {
    services.crowdsec = {
      enable = true;

      settings.general = {
        common.log_level = "info";
        api.server = {
          enable = true;
          listen_uri = "127.0.0.1:8080";
        };
      };

      # Acquisitions: watch haproxy and sshd journals for attack signals.
      localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = ["-u" "haproxy.service"];
          labels.type = "haproxy";
        }
        {
          source = "journalctl";
          journalctl_filter = ["-u" "sshd.service"];
          labels.type = "syslog";
        }
      ];
    };

    # Auto-register the bouncer with a stable key on first boot.
    # Generates a random key, writes it to /var/lib/crowdsec/bouncer-key,
    # and registers it with the LAPI before crowdsec starts.
    systemd.services.crowdsec.serviceConfig.ExecStartPre = [
      (toString (pkgs.writeShellScript "register-bouncer" ''
        set -euo pipefail
        KEY_FILE=/var/lib/crowdsec/bouncer-key
        if [ ! -f "$KEY_FILE" ]; then
          ${pkgs.openssl}/bin/openssl rand -hex 32 > "$KEY_FILE"
          chmod 600 "$KEY_FILE"
        fi
        if ! cscli bouncers list | grep -q "firewall-bouncer"; then
          cscli bouncers add firewall-bouncer --key "$(cat $KEY_FILE)"
        fi
      ''))
    ];

    # Firewall bouncer: bans IPs via nftables before they reach haproxy.
    # Reads the auto-generated key from /var/lib/crowdsec/bouncer-key.
    services.crowdsec-firewall-bouncer = {
      enable = true;
      registerBouncer.enable = false;
      secrets.apiKeyPath = "/var/lib/crowdsec/bouncer-key";

      settings = {
        mode = "nftables";
        api_url = "http://127.0.0.1:8080/";
        update_frequency = "10s";
        log_level = "info";
        deny_action = "DROP";
        deny_log = true;
      };
    };

    # Allow crowdsec to read systemd journal for acquisitions
    users.users.crowdsec.extraGroups = ["systemd-journal"];

    # nftables required for the firewall bouncer
    networking.nftables.enable = true;
  };
}
