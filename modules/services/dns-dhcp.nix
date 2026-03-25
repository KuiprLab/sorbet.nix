_: {
  flake.nixosModules.dnsDhcp = {
    lib,
    ...
  }: let
    serverIp = "192.168.0.85";
    networkInterface = "enp4s0";
  in {
    # -------------------------------------------------------------------------
    # dnsmasq — handles both DHCP and DNS (.lan wildcard)
    # -------------------------------------------------------------------------
    services.dnsmasq = {
      enable = true;
      settings = {
        # Network interface to listen on
        interface = networkInterface;
        bind-interfaces = true;

        # DNS: forward all *.lan queries to ourselves, everything else upstream
        address = "/.lan/${serverIp}";
        server = [ "1.1.1.1" "8.8.8.8" ];

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
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 67 68 ];
    };

    # Disable systemd-resolved to avoid port 53 conflict
    services.resolved.enable = lib.mkForce false;
  };
}
