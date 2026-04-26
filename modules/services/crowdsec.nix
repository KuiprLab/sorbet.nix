# CrowdSec security engine + firewall bouncer for eclair
# Agent detects attacks; firewall bouncer enforces bans via nftables.
# TCP-mode haproxy can't use lua/SPOE bouncer, so IP banning happens
# at the nftables layer — blocks before haproxy ever sees the connection.
#
# First-boot manual steps:
#   cscli hub update
#   cscli collections install crowdsecurity/linux
#   cscli collections install crowdsecurity/haproxy
#   cscli bouncers add firewall-bouncer   # copy the key out, store in sops secret
_: {
  flake.eclairNixosModules.crowdsec = {config, ...}: {
    services.crowdsec = {
      enable = true;

      settings.general = {
        common.log_level = "info";
        api.server = {
          listen_uri = "127.0.0.1:8080";
          # Register with CrowdSec Central API for community blocklists.
          # Run: cscli capi register   after first boot.
          online_client.credentials_path = "/var/lib/crowdsec/online_api_credentials.yaml";
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

    # Firewall bouncer: bans IPs via nftables before they reach haproxy.
    services.crowdsec-firewall-bouncer = {
      enable = true;

      # Disable auto-registration (DynamicUser conflict with crowdsec service).
      # Manually run: cscli bouncers add firewall-bouncer
      # then store the key in the sops secret below.
      registerBouncer.enable = false;

      secrets.apiKeyPath = config.sops.secrets."crowdsec/bouncer-api-key".path;

      settings = {
        mode = "nftables";
        api_url = "http://127.0.0.1:8080/";
        update_frequency = "10s";
        log_level = "info";
        deny_action = "DROP";
        deny_log = true;
      };
    };

    sops.secrets."crowdsec/bouncer-api-key" = {
      sopsFile = ../../secrets/eclair/crowdsec;
      format = "binary";
      key = "";
      owner = "root";
    };

    # Allow crowdsec to read systemd journal for acquisitions
    users.users.crowdsec.extraGroups = ["systemd-journal"];

    # nftables required for the firewall bouncer
    networking.nftables.enable = true;
  };
}
