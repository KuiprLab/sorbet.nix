{
  self,
  inputs,
  ...
}: let
  user = "daniel";
in {
  flake.nixosModules.sorbetConfiguration = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      self.nixosModules.sorbetHardwareConfiguration
    ];

    system.stateVersion = "24.05";

    environment.systemPackages = with pkgs; [
      # Base system
      neovim
      git
      just
      curl
    ];

    virtualisation = {
      podman = {
        enable = true;
        extraPackages = [pkgs.podman-compose];
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
          flags = ["--all"];
        };
      };
      # Enable container features
      containers.enable = true;
    };

    # Networking
    networking = {
      hostName = "sorbet";
      networkmanager.enable = true;
      useDHCP = lib.mkDefault true;
      # TODO: Update
      # interfaces."enp4s0".wakeOnLan.enable = true;
    };

    # Nix settings
    nix = {
      channel.enable = false;
      extraOptions = ''
        experimental-features = nix-command flakes
        warn-dirty = false
      '';
      settings = {
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
    };

    # Time and locale
    time.timeZone = "Europe/Berlin";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "de_DE.UTF-8";
      LC_IDENTIFICATION = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NAME = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TELEPHONE = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
    };

    environment.pathsToLink = [
      "/libexec"
    ];

    # Services
    services = {
      openssh.enable = true;
      pipewire = {
        enable = true;
        alsa = {
          enable = true;
        };
        pulse.enable = true;
      };
    };

    # User configuration
    programs.fish.enable = true;
    users = {
      defaultUserShell = pkgs.fish;
      users.${user} = {
        isNormalUser = true;
        description = user;
        initialPassword = "nixos";
        extraGroups = [
          "networkmanager"
          "root"
          "wheel"
        ];
      };
    };

    # Documentation
    # documentation = {
    #   enable = true;
    #   man = {
    #     enable = true;
    #     man = {
    #       enable = true;
    #       cache.enable = true;
    #     };
    #     dev.enable = true;
    #   };
    #
    # };

    # Home Manager
    home-manager.users.${user} = _: {
      home = {
        stateVersion = "23.11";
        username = user;
        homeDirectory = "/home/${user}";
        sessionVariables = {
          EDITOR = "nvim";
        };
      };
      programs.home-manager.enable = true;
    };
  };
}
