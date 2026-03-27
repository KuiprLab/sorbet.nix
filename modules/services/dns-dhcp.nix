_: {
  flake.gatusEndpoints = [
    {
      name = "DNS";
      url = "192.168.0.85";
      dns = {
        query-name = "has.int.kuipr.de";
        query-type = "A";
      };
      conditions = ["[DNS_RCODE] == NOERROR"];
      alerts = [{type = "discord";}];
    }
  ];

  flake.nixosModules.dnsDhcp = {lib, ...}: let
    serverIp = "192.168.0.85";
    networkInterface = "enp0s31f6";
  in {
    # -------------------------------------------------------------------------
    # dnsmasq — handles both DHCP and DNS (.lan wildcard)
    # -------------------------------------------------------------------------
    services.dnsmasq = {
      enable = true;
      settings = {
        # Network interface to listen on
        interface = [networkInterface];
        bind-interfaces = true;

        # DNS: forward all *.int.kuipr.de queries to ourselves, everything else upstream
        address = "/.int.kuipr.de/${serverIp}";
        server = [
          "9.9.9.9"
          "9.9.9.10"
        ];

        # DHCP: hand out IPs in range, tell clients to use us as DNS
        dhcp-range = "192.168.0.2,192.168.0.254,255.255.255.0,24h";
        dhcp-option = [
          "option:router,192.168.0.1"
          "option:dns-server,${serverIp}"
        ];

        # Static lease for sorbet itself
        dhcp-host = "18:31:bf:b7:fd:3f,sorbet,${serverIp},infinite";

        # Don't read /etc/resolv.conf — we are the resolver
        no-resolv = true;

        # Log DHCP leases
        log-dhcp = true;
      };
    };

    # Open firewall ports
    networking = {
      # Set this to false so the server doesn't go boom if dnsmasq fails to start and takes down the local resolver with it
      resolvconf.useLocalResolver = false;
      firewall = {
        allowedTCPPorts = [53];
        allowedUDPPorts = [
          53
          67
          68
        ];
        interfaces."tailscale0".allowedTCPPorts = [53];
        interfaces."tailscale0".allowedUDPPorts = [53];
      };
    };

    # Disable systemd-resolved to avoid port 53 conflict
    services.resolved.enable = lib.mkForce false;
  };
}
