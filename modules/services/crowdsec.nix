# CrowdSec security engine + firewall bouncer for eclair
# Agent detects attacks; firewall bouncer enforces bans via nftables.
# TCP-mode haproxy can't use lua/SPOE bouncer, so IP banning happens
# at the nftables layer — blocks before haproxy ever sees the connection.
#
# The bouncer API key is auto-generated on first boot via an ExecStartPre
# script on the crowdsec service — no manual steps required.
{lib, ...}: {
  flake.eclairNixosModules.crowdsec = {pkgs, ...}: {
    services.crowdsec = {
      enable = true;

      # Required: tells the module where to write the LAPI credentials file.
      # Without this, api.client.credentials_path is null and the unit fails to evaluate.
      settings.lapi.credentialsFile = "/var/lib/crowdsec/lapi-credentials.yaml";

      settings.general.api.server.enable = true;

      # Install collections via the hub option so the module handles it.
      hub.collections = [
        "crowdsecurity/linux"
        "crowdsecurity/haproxy"
      ];

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
    # Appended after the module's own ExecStartPre entries.
    systemd.services.crowdsec.serviceConfig.ExecStartPre = lib.mkAfter [
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

    # nftables required for the firewall bouncer
    networking.nftables.enable = true;
  };
}
