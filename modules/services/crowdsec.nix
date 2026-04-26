# CrowdSec security engine + firewall bouncer for eclair
# Agent detects attacks; firewall bouncer enforces bans via nftables.
# TCP-mode haproxy can't use lua/SPOE bouncer, so IP banning happens
# at the nftables layer — blocks before haproxy ever sees the connection.
#
# After first successful deploy, install collections manually:
#   cscli hub update
#   cscli collections install crowdsecurity/linux crowdsecurity/haproxy
_: {
  flake.eclairNixosModules.crowdsec = {lib, ...}: {
    services.crowdsec = {
      enable = true;

      # Point lapi credentials to a writable runtime path.
      # This wires up api.client.credentials_path in the generated config.
      settings.lapi.credentialsFile = "/var/lib/crowdsec/lapi-credentials.yaml";

      # mkForce to win over the module's own lib.mkDefault false.
      settings.general.api.server.enable = lib.mkForce true;

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
    # registerBouncer.enable = true uses the built-in register service which
    # runs after crowdsec, calls cscli bouncers add, and saves the key.
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
