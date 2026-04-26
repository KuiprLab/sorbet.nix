# CrowdSec security engine + firewall bouncer for eclair
# Agent detects attacks; firewall bouncer enforces bans via nftables.
# TCP-mode haproxy can't use lua/SPOE bouncer, so IP banning happens
# at the nftables layer — blocks before haproxy ever sees the connection.
#
# Uses nixpkgs PR #446307 (TornaxO7/nixpkgs:crowdsec) which fixes the
# broken module architecture (config.yaml symlink, DynamicUser issues, etc.)
_: {
  flake.eclairNixosModules.crowdsec = _: {
    services.crowdsec = {
      enable = true;

      hub.collections = [
        "crowdsecurity/linux"
        "crowdsecurity/haproxy"
      ];

      # Acquisitions: watch haproxy and sshd journals for attack signals.
      settings.acquisitions = [
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
    # registerBouncer.enable = true uses the built-in register service.
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
