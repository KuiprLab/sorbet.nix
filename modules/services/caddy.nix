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
    # The intermediate key password must be in a file (not in the Nix store)
    # Create with: echo "your-password" > /var/lib/step-ca/password.txt && chmod 600 /var/lib/step-ca/password.txt
    services.step-ca = {
      enable = true;
      address = "127.0.0.1";
      port = 9000;
      intermediatePasswordFile = "/var/lib/step-ca/password.txt";
      settings = builtins.fromJSON (builtins.readFile /var/lib/step-ca/config/ca.json);
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
