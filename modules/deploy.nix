{self, inputs,...}: {
    flake.deploy.nodes =let 
        user = "daniel";
    in{
    sorbet = {
      hostname = "sorbet";
      profiles.system = {
        inherit user;
        sshUser = user;
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.sorbet;
      };
    };
  };
}
