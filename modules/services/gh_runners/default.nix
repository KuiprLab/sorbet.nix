_: {
  flake.nixosModules.caddy = {
    pkgs,
    config,
    inputs,
    ...
  }: {
    sops.secrets = {
      "gh_runner" = {
        sopsFile = ./token;
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
      };
    };
  };
}
