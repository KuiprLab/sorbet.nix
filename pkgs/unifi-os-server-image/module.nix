{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.unifi-os-server;
  stateDir = "/var/lib/unifi-os";

  # Capture unifi-core stdout/stderr to readable files
  # (the container's journal is only accessible as root)
  ucoreDebug = pkgs.writeText "unifi-core-debug.conf" ''
    [Service]
    StandardOutput=append:/data/unifi-core/logs/stdout.log
    StandardError=append:/data/unifi-core/logs/stderr.log
  '';

  # Fix missing directories that services expect but don't create on first run.
  ucorePreStartFix = pkgs.writeText "unifi-core-prestart-fix.conf" ''
    [Service]
    ExecStartPre=-/bin/mkdir -p /data/unifi-core/config/http
    ExecStartPre=-/bin/mkdir -p /var/log/nginx
  '';

  # MongoDB needs writable log and data dirs; + runs as root regardless of User=
  mongoPreStartFix = pkgs.writeText "mongodb-prestart-fix.conf" ''
    [Service]
    ExecStartPre=+/bin/bash -c "mkdir -p /var/log/mongodb && chown mongodb:mongodb /var/log/mongodb /var/lib/mongodb"
  '';

  # Exact image name:tag embedded in `image.tar`.
  # Must match the repository:tag inside the archive.
  imageTag = "uosserver:0.0.54";
in {
  # reverse engineered via
  # https://www.unihosted.com/blog/running-unifi-os-server-in-docker
  options.services.unifi-os-server = {
    enable = mkEnableOption "UniFi OS Server container (podman)";

    package = mkOption {
      type = types.package;
      description = ''
        Package containing the extracted UniFi OS Server OCI archive at
        `image.tar`.  Build with:
        `pkgs.callPackage ./package.nix { sha256 = "…"; }`
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether or not to open the minimum required ports on the firewall.

        This is necessary to allow firmware upgrades and device discovery to
        work. For remote login, you should additionally open (or forward) port
        8443.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Additional environment variables for the container.";
    };

    extraVolumes = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["/etc/ssl/certs:/etc/rabbitmq/ssl:ro"];
      description = "Additional bind mounts beyond the defaults.";
    };

    extraOptions = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra arguments passed to podman.";
    };
  };

  config = mkIf cfg.enable {
    virtualisation = {
      podman.enable = true;
      oci-containers.backend = "podman";
    };

    # https://www.crosstalksolutions.com/complete-unifi-os-server-installation-on-linux-best-practices/
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [
        9443 # UniFi OS dashboard HTTPS
        8080 # UAP device inform
        8443 # Controller HTTPS
        8843 # HTTPS portal redirect
        8880 # HTTP portal redirect
        6443 # UniFi OS internal
        6789 # Mobile speed test
      ];
      allowedUDPPorts = [
        3478 # STUN
        10001 # Device discovery
      ];
    };

    systemd.services.podman-unifi-os-server = {
      # Make sure package upgrades trigger a service restart
      restartTriggers = [cfg.package];

      serviceConfig = {
        StateDirectory = [
          "unifi-os"
          "unifi-os/persistent"
          "unifi-os/data"
          "unifi-os/srv"
          "unifi-os/unifi"
          "unifi-os/mongodb"
        ];
        LogsDirectory = "unifi-os";
      };

      preStart = lib.mkAfter ''
        uuid_file="${stateDir}/data/uos_uuid"
        # The Java UniFi controller requires exactly UUID v5 (SHA-1 name-based).
        # Generate a stable v5 UUID derived from the machine-id.
        if ! grep -qP '^[0-9a-f]{8}-[0-9a-f]{4}-5' "$uuid_file" 2>/dev/null; then
          ${pkgs.util-linux}/bin/uuidgen -s -n @dns -N "$(cat /etc/machine-id)" > "$uuid_file"
        fi

      '';
    };

    virtualisation.oci-containers.containers.unifi-os-server = {
      image = imageTag;
      imageFile = pkgs.runCommand "unifi-os-image.tar" {} ''
        ln -s ${cfg.package}/image.tar $out
      '';
      autoStart = true;
      privileged = true;

      environment =
        {
          UOS_SYSTEM_IP = "127.0.0.1";
          UOS_SERVER_VERSION = cfg.package.version;
          FIRMWARE_PLATFORM =
            if pkgs.stdenv.hostPlatform.isAarch64
            then "linux-arm64"
            else "linux-x64";
        }
        // cfg.environment;

      volumes =
        [
          "${stateDir}/persistent:/persistent"
          "/var/log/unifi-os:/var/log"
          "${stateDir}/data:/data"
          "${stateDir}/srv:/srv"
          "${stateDir}/unifi:/var/lib/unifi"
          "${stateDir}/mongodb:/var/lib/mongodb"
          "${ucoreDebug}:/etc/systemd/system/unifi-core.service.d/debug.conf:ro"
          "${ucorePreStartFix}:/etc/systemd/system/unifi-core.service.d/prestart-fix.conf:ro"
          "${mongoPreStartFix}:/etc/systemd/system/mongodb.service.d/prestart-fix.conf:ro"
        ]
        ++ cfg.extraVolumes;

      extraOptions =
        [
          "--systemd=always"
          "--network=host"
          "--cap-add=SYS_ADMIN"
          "--cap-add=DAC_READ_SEARCH"
        ]
        ++ cfg.extraOptions;
    };
  };
}
