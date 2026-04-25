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
      # Replace with eclair's public IP or hostname after provisioning.
      hostname = "46.38.236.192";
      profiles.system = {
        inherit user;
        sshUser = user;
        remoteBuild = false; # build locally, push closure to VPS
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.eclair;
      };
    };
  };
}
