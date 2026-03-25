_: {
  flake.nixosModules.dnsDhcp = {
    lib,
    pkgs,
    ...
  }: let
    serverIp = "192.168.0.85";
    networkInterface = "enp4s0";
    domain = "lan";
  in {
    # -------------------------------------------------------------------------
    # DHCP Server (ISC dhcpd)
    # -------------------------------------------------------------------------
    services.dhcpd4 = {
      enable = true;
      interfaces = [ networkInterface ];
      extraConfig = ''
        option domain-name "${domain}";
        option domain-name-servers ${serverIp};
        option routers 192.168.0.1;

        default-lease-time 86400;
        max-lease-time 86400;

        subnet 192.168.0.0 netmask 255.255.255.0 {
          range 192.168.0.2 192.168.0.254;
          option broadcast-address 192.168.0.255;
        }

        host sorbet {
          hardware ethernet 18:31:bf:b7:fd:3f;
          fixed-address ${serverIp};
        }
      '';
    };

    # -------------------------------------------------------------------------
    # BIND9 DNS Server
    # -------------------------------------------------------------------------
    services.bind = {
      enable = true;
      # Only listen on LAN interface + loopback
      listenOn = [ "${serverIp}" "127.0.0.1" ];
      # Allow queries from local network only
      cacheNetworks = [ "192.168.0.0/24" "127.0.0.0/8" ];

      forwarders = [
        "1.1.1.1"
        "8.8.8.8"
      ];

      zones = {
        # Forward zone: resolve *.lan to this server
        "${domain}" = {
          master = true;
          file = pkgs.writeText "db.lan" ''
            $TTL 3600
            @ IN SOA ns.lan. admin.lan. (
              2024010101 ; Serial
              3600       ; Refresh
              1800       ; Retry
              604800     ; Expire
              3600 )     ; Negative Cache TTL

            @ IN NS ns.lan.

            ; All *.lan queries resolve to this server
            ; Add your specific service records below
            ns              IN A ${serverIp}
            @               IN A ${serverIp}
            *               IN A ${serverIp}
          '';
        };

        # Reverse zone for 192.168.0.x
        "0.168.192.in-addr.arpa" = {
          master = true;
          file = pkgs.writeText "db.192.168.0" ''
            $TTL 3600
            @ IN SOA ns.lan. admin.lan. (
              2024010101 ; Serial
              3600       ; Refresh
              1800       ; Retry
              604800     ; Expire
              3600 )     ; Negative Cache TTL

            @ IN NS ns.lan.

            85 IN PTR sorbet.lan.
          '';
        };
      };
    };

    # Open firewall ports
    networking.firewall = {
      allowedTCPPorts = [
        53  # DNS
        67  # DHCP
      ];
      allowedUDPPorts = [
        53  # DNS
        67  # DHCP
        68  # DHCP client
      ];
    };

    # Disable systemd-resolved to avoid port 53 conflicts
    services.resolved.enable = lib.mkForce false;
  };
}
