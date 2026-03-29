_: {
  flake.nixosModules.caddy = {config, ...}: {
    sops.secrets = {
      "gh_runner" = {
        sopsFile = ../../secrets/github-secrets;
        format = "binary";
        key = "";
      };
    };

    services.github-runners = {
      deploy = {
        enable = true;
        name = "deploy-runner";
        tokenFile = config.sops.secrets."gh_runner".path;
        url = "https://github.com/KuiprLab/sorbet.nix";
        serviceOverrides = {
          restartIfChanged = false;
          # Don't stop during nixos-rebuild switch
          X-StopOnReconfiguration = false;
        };
      };
    };
  };
}
