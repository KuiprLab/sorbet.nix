{
  self,
  inputs,
  ...
}: {
  flake.deploy.nodes = let
    user = "daniel";
  in {
    sorbet = {
      hostname = "192.168.0.85";
      profiles.system = {
        uset = "root";
        sshUser = user;
        remoteBuild = true;
        interactiveSudo = false;
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.sorbet;
      };
    };
  };
}
