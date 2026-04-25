# eclair — tiny public VPS
# Runs haproxy (TCP SNI proxy) + CrowdSec, connected via tailnet.
# Routes *.ext.kuipr.de → sorbet's tailscale IP (caddy terminates TLS).
{
  self,
  inputs,
  lib,
  config,
  ...
}: let
  collectModules = attrs: lib.attrValues (lib.filterAttrs (_n: v: v != {}) attrs);

  # Set this to the output of `tailscale ip -4` on sorbet after eclair joins the tailnet.
  sorbetTailscaleIp = "100.120.32.9";
in {
  options.flake.eclairNixosModules = lib.mkOption {
    type = lib.types.attrsOf lib.types.raw;
    default = {};
  };

  config.flake.nixosConfigurations.eclair = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules =
      [
        self.nixosModules.eclairConfiguration
        self.nixosModules.eclairHardwareConfiguration
        inputs.sops-nix.nixosModules.sops
        inputs.determinate.nixosModules.default
        {
          nixpkgs.config = {
            allowUnfree = true;
            allowBroken = false;
          };
          # Pass sorbet's tailscale IP into haproxy module
          _module.args.sorbetTailscaleIp = sorbetTailscaleIp;
          # Make caddyVirtualHosts available inside nixos modules
          flake.caddyVirtualHosts = config.flake.caddyVirtualHosts;
        }
      ]
      ++ collectModules self.eclairNixosModules;
  };
}
