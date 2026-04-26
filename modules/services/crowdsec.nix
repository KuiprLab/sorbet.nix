# CrowdSec security engine + firewall bouncer for eclair
# Agent detects attacks; firewall bouncer enforces bans via nftables.
# TCP-mode haproxy can't use lua/SPOE bouncer, so IP banning happens
# at the nftables layer — blocks before haproxy ever sees the connection.
#
# After first successful deploy, install collections manually:
#   cscli hub update
#   cscli collections install crowdsecurity/linux crowdsecurity/haproxy
_: {
  flake.eclairNixosModules.crowdsec = _: {
    services = {
      crowdsec = {
        enable = true;

        user = "root";
        autoUpdateService = true;
        openFirewall = true;

        # Acquisitions: watch haproxy and sshd journals for attack signals.
        localConfig.acquisitions = [
          {
            source = "journalctl";
            journalctl_filter = [
              "-u"
              "haproxy.service"
            ];
            labels.type = "haproxy";
          }
          {
            source = "journalctl";
            journalctl_filter = [
              "-u"
              "sshd.service"
            ];
            labels.type = "syslog";
          }
        ];
      };

      # crowdsec-firewall-bouncer = {
      #   enable = true;
      #   secrets.apiKeyPath = "";
      # };
    };
    networking.nftables.enable = true;
  };
}
