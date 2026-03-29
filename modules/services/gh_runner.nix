_: {
  flake.nixosModules.caddy = {config, ...}: {
    sops.secrets = {
      "gh_runner/gh_secret" = {
        sopsFile = ../../secrets/github-secrets;
        format = "binary";
        key = "";
      };

      "gh_runner/deploy_webhook" = {
        sopsFile = ../../secrets/deploy_webhook;
        format = "binary";
        key = "";
        owner = "root";
      };
    };

    services.github-runners = {
      deploy = {
        enable = true;
        name = "deploy-runner";
        tokenFile = config.sops.secrets."gh_runner/gh_secret".path;
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
