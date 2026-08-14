{
  self,
  inputs,
  ...
}: {
  flake.deploy.nodes = let
    user = "root";
  in {
    sorbet = {
      hostname = "192.168.0.85";
      profiles.system = {
        inherit user;
        sshUser = user;
        remoteBuild = true;
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.sorbet;
      };
    };

    eclair = {
      # Tailnet IP — the public IP refuses port 22 (provider firewall).
      # Set to the output of `tailscale ip -4 eclair`.
      hostname = "100.99.168.34";
      # Build on sorbet (x86_64-linux), push the closure to eclair.
      # The Mac is arm64 and cannot build x86_64-linux closures.
      buildHost = "sorbet";
      profiles.system = {
        inherit user;
        sshUser = user;
        remoteBuild = false;
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.eclair;
      };
    };
  };
}
