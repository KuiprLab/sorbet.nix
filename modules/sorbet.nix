{ inputs, ... }:
{
  flake.modules.nixos.sorbet =
    {
      pkgs,
      lib,
      config,
      defaults,
      modulesPath,
      inputs,
      ...
    }:
    let
      inherit (defaults) user;
    in
    {
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
        inputs.disko.nixosModules.disko
      ];

      system.stateVersion = "24.05";

      # Boot configuration
      boot = {
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
        kernelPackages = pkgs.linuxPackages_zen;
        initrd = {
          availableKernelModules = [
            "xhci_pci"
            "ahci"
            "nvme"
            "usb_storage"
            "usbhid"
            "sd_mod"
          ];
          kernelModules = [ ];
        };
        kernelModules = [ "kvm-intel" ];
        extraModulePackages = [ ];
      };

      disko.devices = {
        disk = {
          main = {
            type = "disk";
            device = "/dev/nvme0n1";
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  priority = 1;
                  name = "ESP";
                  start = "1M";
                  end = "512M";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [ "umask=0077" ];
                  };
                };
                swap = {
                  size = "35G";
                  type = "8200";
                  content = {
                    type = "swap";
                  };
                };
                root = {
                  size = "100%";
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ];
                    subvolumes = {
                      "/rootfs" = {
                        mountpoint = "/";
                      };
                      "/home" = {
                        mountOptions = [ "compress=zstd" ];
                        mountpoint = "/home";
                      };
                      "/nix" = {
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                        mountpoint = "/nix";
                      };
                      "/persist" = {
                        mountpoint = "/persist";
                      };
                    };
                    mountpoint = "/partition-root";
                  };
                };
              };
            };
          };
        };
      };

      # Networking
      networking = {
        hostName = "sorbet";
        networkmanager.enable = true;
        useDHCP = lib.mkDefault true;
        # TODO: Update
        interfaces."enp4s0".wakeOnLan.enable = true;
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

      # Hardware
      hardware = {
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };

      # Documentation
      documentation = {
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
