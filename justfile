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
      --target-host {{target}} \
      --option substituters "https://nix-community.cachix.org https://cache.nixos.org" --option trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="


# Format all Nix files
fmt:
    nix fmt .

# Run flake checks
check:
    nix flake check --all-systems
