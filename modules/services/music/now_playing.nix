_: {
  flake = {
    caddyVirtualHosts."now_playing.ext.kuipr.de" = ''
      reverse_proxy localhost:8765 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
      }
    '';

    nixosModules.now_playing = {config, ...}: {
      imports = [
        ../../../pkgs/now_playing.nix
      ];

      sops.secrets."now_playing" = {
        sopsFile = ../../../secrets/sorbet/now_playing;
        format = "binary";
        key = "";
        uid = 1000;
      };

      services.now-playing = {
        enable = true;

        navidrome = {
          url = "https://music.ext.kuipr.de";
          username = "daniel";
          passwordFile = config.sops.secrets."now_playing".path;
        };

        allowedOrigins = [
          "https://example.com"
        ];
      };
    };
  };
}
