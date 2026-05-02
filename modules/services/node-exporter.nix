# node_exporter — host-level metrics (CPU, RAM, disk, network).
# Both hosts. Bound to tailscale0 so prometheus on sorbet can scrape eclair.
_: let
  nodeExporterModule = _: {
    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
      # Listen on all interfaces; firewall restricts to tailscale0.
      listenAddress = "0.0.0.0";
      enabledCollectors = [
        "systemd"
        "processes"
        "interrupts"
      ];
      # Disable a few heavyweight collectors that aren't useful here.
      disabledCollectors = [
        "btrfs"
        "infiniband"
        "ipvs"
        "nfs"
        "nfsd"
        "zfs"
      ];
    };

    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [9100];
  };
in {
  flake.nixosModules.nodeExporter = nodeExporterModule;
  flake.eclairNixosModules.nodeExporter = nodeExporterModule;
}
