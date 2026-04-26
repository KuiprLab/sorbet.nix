# CrowdSec security engine + firewall bouncer for eclair
# Agent detects attacks; firewall bouncer enforces bans via nftables.
# TCP-mode haproxy can't use lua/SPOE bouncer, so IP banning happens
# at the nftables layer — blocks before haproxy ever sees the connection.
{lib, ...}: {
  flake.eclairNixosModules.crowdsec = {lib, ...}: {
    services.crowdsec = {
      enable = true;

      # Required: tells the module where to write/read the LAPI credentials.
      # Without this, api.client.credentials_path is null and evaluation fails.
      settings.lapi.credentialsFile = "/var/lib/crowdsec/lapi-credentials.yaml";

      settings.general.api.server.enable = true;

      # Install hub collections declaratively.
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

    # Firewall bouncer: bans IPs via nftables before they reach haproxy.
    # registerBouncer.enable = true uses the built-in crowdsec-firewall-bouncer-register
    # oneshot service which runs after crowdsec, calls cscli bouncers add, and saves
    # the key to its own state directory — fully automatic, no manual steps.
    services.crowdsec-firewall-bouncer = {
      enable = true;
      registerBouncer.enable = true;

      settings = {
        mode = "nftables";
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
