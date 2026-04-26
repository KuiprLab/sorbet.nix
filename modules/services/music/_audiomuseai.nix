{
  pkgs,
  config,
  ...
}: {
  flake.caddyVirtualHosts."musai.int.kuipr.de" = ''
    reverse_proxy localhost:8000 {
      header_up Host {host}
      header_up X-Real-IP {remote_host}
      header_up X-Forwarded-For {remote_host}
      header_up X-Forwarded-Proto {scheme}
    }
  '';

  virtualisation.oci-containers = {
    backend = "podman";

    containers = {
      # -------------------------
      # Redis
      # -------------------------
      audiomuse-redis = {
        image = "redis:7-alpine";

        ports = [
          "${toString (config.services.audiomuse.redisPort or 6379)}:6379"
        ];

        volumes = [
          "redis-data:/data"
        ];

        extraOptions = [
          "--restart=unless-stopped"
        ];
      };

      # -------------------------
      # PostgreSQL
      # -------------------------
      audiomuse-postgres = {
        image = "postgres:15-alpine";

        ports = [
          "${toString (config.services.audiomuse.postgresPort or 5432)}:5432"
        ];

        environment = {
          POSTGRES_USER = "audiomuse";
          POSTGRES_PASSWORD = "audiomusepassword";
          POSTGRES_DB = "audiomusedb";
        };

        volumes = [
          "postgres-data:/var/lib/postgresql/data"
        ];

        extraOptions = [
          "--restart=unless-stopped"
        ];
      };

      # -------------------------
      # Flask App
      # -------------------------
      audiomuse-ai-flask = {
        image = "ghcr.io/neptunehub/audiomuse-ai:latest";

        ports = [
          "8000:8000"
        ];

        environment = {
          SERVICE_TYPE = "flask";
          TZ = "UTC";

          POSTGRES_USER = "audiomuse";
          POSTGRES_PASSWORD = "audiomusepassword";
          POSTGRES_DB = "audiomusedb";
          POSTGRES_HOST = "postgres";
          POSTGRES_PORT = "5432";

          REDIS_URL = "redis://redis:6379/0";
          TEMP_DIR = "/app/temp_audio";
        };

        volumes = [
          "temp-audio-flask:/app/temp_audio"
        ];

        extraOptions = [
          "--restart=unless-stopped"
        ];
      };

      # -------------------------
      # RQ Worker
      # -------------------------
      audiomuse-ai-worker = {
        image = "ghcr.io/neptunehub/audiomuse-ai:latest";

        environment = {
          SERVICE_TYPE = "worker";
          TZ = "UTC";

          POSTGRES_USER = "audiomuse";
          POSTGRES_PASSWORD = "audiomusepassword";
          POSTGRES_DB = "audiomusedb";
          POSTGRES_HOST = "postgres";
          POSTGRES_PORT = "5432";

          REDIS_URL = "redis://redis:6379/0";
          TEMP_DIR = "/app/temp_audio";
        };

        volumes = [
          "temp-audio-worker:/app/temp_audio"
        ];

        extraOptions = [
          "--restart=unless-stopped"
        ];
      };
    };
  };

  # -------------------------
  # Docker volumes
  # -------------------------
  virtualisation.docker = {
    enable = true;
  };

  systemd.services."docker-volume-redis-data" = {
    serviceConfig.Type = "oneshot";
    script = "docker volume create redis-data || true";
    wantedBy = ["multi-user.target"];
  };

  systemd.services."docker-volume-postgres-data" = {
    serviceConfig.Type = "oneshot";
    script = "docker volume create postgres-data || true";
    wantedBy = ["multi-user.target"];
  };

  systemd.services."docker-volume-temp-audio-flask" = {
    serviceConfig.Type = "oneshot";
    script = "docker volume create temp-audio-flask || true";
    wantedBy = ["multi-user.target"];
  };

  systemd.services."docker-volume-temp-audio-worker" = {
    serviceConfig.Type = "oneshot";
    script = "docker volume create temp-audio-worker || true";
    wantedBy = ["multi-user.target"];
  };
}
