{lib, ...}: {
  options.flake.defaults = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Shared default values passed to all configurations via specialArgs";
  };

  config.flake.defaults = {
    user = "daniel";

    system = {
      darwinVersion = 6;
      nixosVersion = "25.11";
      timeZone = "Europe/Berlin";
      locale = "en_US.UTF-8";
    };

    paths = {
      flake = "~/dotfiles.nix";
    };
  };
}

