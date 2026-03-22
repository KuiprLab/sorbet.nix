config := "sorbet"

# Build the NixOS config locally (requires a Linux builder on macOS)
build:
    @git add .
    @nix build ".#nixosConfigurations.sorbet.config.system.build.toplevel" --system x86_64-linux

# Deploy to the server via rsync + SSH
[doc("Deploy the NixOS configuration to the server using nixos-anywhere")]
deploy target:
    #!/usr/bin/env bash
    set -euxo pipefail
    read -s -p "Enter SSH password for {{target}}: " SSHPASS
    echo
    export SSHPASS
    nix run github:nix-community/nixos-anywhere -- --flake .#{{config}} \
      --env-password \
      --option substituters 'https://cache.nixos.org https://frostplexx.cachix.org https://nvf.cachix.org https://nix-community.cachix.org' \
      --option extra-substituters 'https://install.determinate.systems' \
      --option trusted-substituters 'https://cache.nixos.org https://frostplexx.cachix.org https://nvf.cachix.org https://nix-community.cachix.org' \
      --option trusted-public-keys 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= frostplexx.cachix.org-1:kjkhnGNSkUvf5Mx8OEfhzaR830CUkDRglaKduAcr3UQ= nvf.cachix.org-1:GMQWiUhZ6ux9D5CvFFMwnc2nFrUHTeGaXRlVBXo+naI= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=' \
      --option extra-trusted-public-keys cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= \
      --target-host {{target}} 



# Format all Nix files
fmt:
    nix fmt .

# Run flake checks
check:
    nix flake check --all-systems
