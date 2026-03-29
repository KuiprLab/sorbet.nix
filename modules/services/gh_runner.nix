_: {
  flake.nixosModules.gh_runner =
    {
      config,
      pkgs,
      ...
    }:
    {
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
          runtimeInputs = [
            pkgs.curl
            pkgs.jq
            pkgs.dix
            pkgs.coreutils
          ];
          text = ''
            WEBHOOK=$(cat ${config.sops.secrets."deploy_webhook".path})

            OLD=$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' | sort -t- -k2 -n | tail -1)

            nixos-rebuild switch --flake "github:KuiprLab/sorbet.nix#sorbet" > /tmp/deploy.log 2>&1
            EXIT=$?

            NEW=/run/current-system

            DIFF=$(dix --color never "''${OLD}" "''${NEW}" 2>/dev/null || echo "Could not generate diff")

            if [ "''${EXIT}" -eq 0 ]; then
              BODY=$(printf "%s\n%s\n%s\n%s\n%s" \
                "SUCCESS: sorbet deploy succeeded" \
                "**Changes:**" \
                '```diff' \
                "''${DIFF}" \
                '```')
            else
              ERRORS=$(tail -20 /tmp/deploy.log)
              BODY=$(printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s" \
                "FAILED: sorbet deploy failed (exit ''${EXIT})" \
                "**Changes attempted:**" \
                '```diff' \
                "''${DIFF}" \
                '```' \
                "**Error:**" \
                '```' \
                "''${ERRORS}" \
                '```')
            fi

            CONTENT=$(printf '%s' "''${BODY}" | head -c 1900)

            curl -s -X POST "''${WEBHOOK}" \
              -H "Content-Type: application/json" \
              -d "{\"content\": $(printf '%s' "''${CONTENT}" | jq -Rs .)}"
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
