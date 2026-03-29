_: {
  flake.nixosModules.gh_runner = {
    config,
    pkgs,
    ...
  }: {
    sops.secrets = {
      "gh_runner" = {
        sopsFile = ../../secrets/github-secrets;
        format = "binary";
        key = "";
      };

      "deploy_webhook" = {
        sopsFile = ../../secrets/deploy_webhook;
        format = "binary";
        key = "";
        owner = "root";
      };
    };

    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "actions-deploy";
        runtimeInputs = [pkgs.curl pkgs.nixos-rebuild];
        text = ''
          nixos-rebuild switch --flake "github:KuiprLab/sorbet.nix#sorbet" > /tmp/deploy.log 2>&1
          EXIT=$?

          WEBHOOK=$(cat ${config.sops.secrets."deploy_webhook".path})

          if [ "$EXIT" -eq 0 ]; then
            MSG="✅ **sorbet deploy succeeded**"
          else
            MSG="❌ **sorbet deploy FAILED** (exit $EXIT)\n\`\`\`$(tail -20 /tmp/deploy.log)\`\`\`"
          fi

          curl -s -X POST "$WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"$MSG\"}"
        '';
      })
    ];

    services.github-runners = {
      deploy = {
        enable = true;
        name = "deploy-runner";
        tokenFile = config.sops.secrets."gh_runner".path;
        url = "https://github.com/KuiprLab/sorbet.nix";
        serviceOverrides = {
          restartIfChanged = false;
          X-StopOnReconfiguration = false;
        };
      };
    };
  };
}
