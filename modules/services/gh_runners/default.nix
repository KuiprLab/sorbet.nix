_: {
  flake.nixosModules.caddy = {
    pkgs,
    config,
    inputs,
    ...
  }: {
    inputs.sops.secrets = {
      "token" = {
        sopsFile = ./token;
        format = "binary";
        key = "";
      };
    };

    services.github-runners = {
      deploy = {
        enable = true;
        name = "deploy-runner";
        tokenFile = "${config.sops.secrets.token.sopsFile}";
        url = "https://github.com/KuiprLab/sorbet.nix";
      };
    };
  };
}
