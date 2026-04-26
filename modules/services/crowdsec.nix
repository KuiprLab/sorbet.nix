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

    # Prevent bouncer and register service from blocking activation.
    # They will start after crowdsec is up but failures won't roll back the deploy.
    systemd.services.crowdsec-firewall-bouncer-register = {
      unitConfig.StartLimitBurst = 3;
      serviceConfig = {
        # DynamicUser conflicts with pre-existing /var/lib/crowdsec owned by crowdsec user.
        DynamicUser = lib.mkForce false;
        User = "crowdsec";
        Group = "crowdsec";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    systemd.services.crowdsec-firewall-bouncer.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
    };

    # nftables required for the firewall bouncer
    networking.nftables.enable = true;
  };
}
