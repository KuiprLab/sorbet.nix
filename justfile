config := "sorbet"

# Build the NixOS config locally (requires a Linux builder on macOS)
build:
    @git add .
    @nix build ".#nixosConfigurations.sorbet.config.system.build.toplevel" --system x86_64-linux

# Deploy to the server via rsync + SSH
deploy:
    @orb push . ~/
    @orb sudo nixos-rebuild switch --flake /home/daniel/sorbet.nix#{{config}} --option substituters "https://nix-community.cachix.org https://cache.nixos.org" --option trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="


# Format all Nix files
fmt:
    nix fmt .

# Run flake checks
check:
    nix flake check --all-systems
