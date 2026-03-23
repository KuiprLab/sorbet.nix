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
        inherit user;
        sshUser = user;
        sudo = "sudo -u";
        remoteBuild = true;
        interactiveSudo = true;
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.sorbet;
      };
    };
  };
}
