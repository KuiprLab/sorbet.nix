{
  lib,
  config,
  ...
}: {
  options.flake.caddyVirtualHosts = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {};
    description = ''
      Caddy virtual host configurations contributed by service modules.
      Keys are hostnames, values are Caddyfile site block bodies (extraConfig).
    '';
  };

  config.flake.nixosModules.stepCa = _: {
    systemd.services."step-ca".serviceConfig = {
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
      DynamicUser = lib.mkForce false;
    };

    # The intermediate key password must be in a file (not in the Nix store)
    # Create with: echo "your-password" > /var/lib/step-ca/password.txt && chmod 600 /var/lib/step-ca/password.txt
    services.step-ca = {
      enable = true;
      address = "127.0.0.1";
      port = 9000;
      intermediatePasswordFile = "/var/lib/step-ca/password.txt"; # or a sops secret path

      settings = {
        root = "/var/lib/step-ca/certs/root_ca.crt";
        crt = "/var/lib/step-ca/certs/intermediate_ca.crt";
        key = "/var/lib/step-ca/secrets/intermediate_ca_key";
        dnsNames = [
          "localhost"
          "sorbet.lan"
        ];
        logger.format = "text";

        authority = {
          provisioners = [
            {
              type = "ACME";
              name = "acme";
              # 90-day cert lifetime
              claims = {
                minTLSCertDuration = "5m";
                maxTLSCertDuration = "2160h";
                defaultTLSCertDuration = "2160h";
              };
            }
          ];
        };

        db = {
          type = "badgerv2";
          dataSource = "/var/lib/step-ca/db";
        };
      };
    };
  };

  config.flake.nixosModules.caddy = let
    virtualHosts = config.flake.caddyVirtualHosts;
  in
    _: {
      # caddy redirects to 443 automagically
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      systemd.services.caddy = {
        after = ["step-ca.service"];
        wants = ["step-ca.service"];
      };

      services.caddy = {
        enable = true;
        virtualHosts = lib.mapAttrs (_: extraConfig: {inherit extraConfig;}) virtualHosts;
        globalConfig = ''
          acme_ca https://localhost:9000/acme/acme/directory
          acme_ca_root /var/lib/step-ca/certs/root_ca.crt
        '';
      };
    };
}
