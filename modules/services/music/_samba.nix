# Samba shares and firewall rules for music folders
{
  musicFolder,
  inboxFolder,
  ...
}: let
  mkSambaShare = path: {
    "path" = path;
    "browseable" = "yes";
    "read only" = "no";
    "guest ok" = "no";
    "valid users" = ["daniel"];
    "create mask" = "0644";
    "directory mask" = "0755";
  };
in {
  # TODO: add `sudo smbpasswd -a daniel` as a post-deploy step
  services = {
    samba = {
      enable = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "music-server";
          "security" = "user";
          "invalid users" = ["root"];
        };
        music = mkSambaShare musicFolder;
        inbox = mkSambaShare inboxFolder;
      };
    };

    samba-wsdd.enable = true;
  };

  networking.firewall = {
    allowedTCPPorts = [
      445
      139
    ];
    allowedUDPPorts = [
      137
      138
      5355
      3702
    ];
  };
}
