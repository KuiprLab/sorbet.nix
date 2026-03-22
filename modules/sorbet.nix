_: {
  flake.modules.nixos.sorbet = {
    pkgs,
    lib,
    config,
    defaults,
    inputs,
    modulesPath,
    ...
  }: let
    inherit (defaults) user;
  in {

  imports =
    [ # Include the results of the hardware scan.
(modulesPath + "/installer/scan/not-detected.nix")
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;


  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/82c51ce1-bd98-46e5-85be-2185b36572b2";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/382A-C4BF";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [ ];

    system.stateVersion = "24.05";

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
      time.timeZone = defaults.system.timeZone;
      i18n.defaultLocale = defaults.system.locale;
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
    documentation = {
      enable = true;
      man = {
        enable = true;
        man = {
          enable = true;
          cache.enable = true;
        };
        dev.enable = true;
      };

      # Home Manager
      home-manager.users.${user} = _: {
        home = {
          stateVersion = "23.11";
          username = user;
          homeDirectory = "/home/${user}";
          sessionVariables = {
            NH_FLAKE = "$HOME/${defaults.paths.flake}";
            EDITOR = "nvim";
          };
        };
        programs.home-manager.enable = true;
      };
    };
}
