{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.now-playing;
  jsonFormat = pkgs.formats.json {};
in {
  options.services.now-playing = {
    enable = lib.mkEnableOption "Now Playing API service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python3;
      description = "Python package used to run the service.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address to bind to.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "now-playing";
      description = "User to run the now-playing service as.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8765;
      description = "Port to bind to.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall port.";
    };

    navidrome = {
      url = lib.mkOption {
        type = lib.types.str;
        example = "https://navidrome.example.com";
      };

      username = lib.mkOption {
        type = lib.types.str;
      };

      passwordFile = lib.mkOption {
        type = lib.types.path;
        description = "Path to a file containing the Navidrome password.";
      };
    };

    allowedOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [
        "https://example.com"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

    systemd.services.now-playing = let
      settingsFile = jsonFormat.generate "now-playing-config.json" {
        inherit (cfg) host port allowedOrigins;
        navidrome = {
          inherit (cfg.navidrome) url username;
        };
      };

      app =
        pkgs.writeText "now-playing.py"
        /*
        python
        */
        ''
          import hashlib
          import json
          import secrets
          from pathlib import Path

          import requests

          from fastapi import FastAPI
          from fastapi.middleware.cors import CORSMiddleware
          from fastapi.responses import JSONResponse, Response

          CONFIG = json.loads(
              Path("${settingsFile}").read_text()
          )

          PASSWORD = Path(
              "${cfg.navidrome.passwordFile}"
          ).read_text().strip()

          NAVIDROME_URL = CONFIG["navidrome"]["url"]
          USERNAME = CONFIG["navidrome"]["username"]

          app = FastAPI()

          if CONFIG["allowedOrigins"]:
              app.add_middleware(
                  CORSMiddleware,
                  allow_origins=CONFIG["allowedOrigins"],
                  allow_methods=["GET"],
                  allow_headers=["*"],
              )

          def auth_params():
              salt = secrets.token_hex(6)

              token = hashlib.md5(
                  (PASSWORD + salt).encode()
              ).hexdigest()

              return {
                  "u": USERNAME,
                  "t": token,
                  "s": salt,
                  "v": "1.16.1",
                  "c": "now-playing-widget",
                  "f": "json",
              }

          @app.get("/")
          def root():
             return {"status": "ok", "endpoint": "/now-playing"}

          @app.get("/widget", response_class=HTMLResponse)
          def widget():
              return """
          <!doctype html>
          <html>
          <head>
            <meta charset="utf-8" />
            <style>
              body {
                margin: 0;
                font-family: sans-serif;
                background: transparent;
                color: white;
              }
              .box {
                display: flex;
                align-items: center;
                gap: 10px;
                padding: 8px;
              }
              img {
                width: 48px;
                height: 48px;
                border-radius: 6px;
              }
              .meta {
                display: flex;
                flex-direction: column;
                font-size: 12px;
              }
            </style>
          </head>
          <body>
            <div class="box" id="content">Loading...</div>

            <script>
              async function load() {
                try {
                  const res = await fetch("/now-playing");
                  const data = await res.json();

                  const el = document.getElementById("content");

                  if (!data.playing) {
                    el.innerHTML = "Nothing playing";
                    return;
                  }

                  el.innerHTML = `
                    <img src="${data.coverArt}" />
                    <div class="meta">
                      <strong>${data.title}</strong>
                      <span>${data.artist}</span>
                    </div>
                  `;
                } catch (e) {
                  document.getElementById("content").innerText = "Error loading";
                }
              }

              load();
              setInterval(load, 10000);
            </script>
          </body>
          </html>
          """

          @app.get("/now-playing")
          def now_playing():
              params = auth_params()

              response = requests.get(
                  f"{NAVIDROME_URL}/rest/getNowPlaying.view",
                  params=params,
                  timeout=5,
              )

              data = response.json()

              entries = (
                  data.get("subsonic-response", {})
                  .get("nowPlaying", {})
                  .get("entry", [])
              )

              if not entries:
                  return JSONResponse(
                      {
                          "playing": False,
                      },
                      headers={
                          "Cache-Control": "public, max-age=10"
                      },
                  )

              song = entries[0]

              return JSONResponse(
                  {
                      "playing": True,
                      "title": song.get("title"),
                      "artist": song.get("artist"),
                      "album": song.get("album"),
                      "coverArt": (
                          f"/cover/{song.get('coverArt')}"
                      ),
                      "coverId": song.get("coverArt"),
                      "duration": song.get("duration"),
                  },
                  headers={
                      "Cache-Control": "public, max-age=10"
                  },
              )

          @app.get("/cover/{cover_id}")
          def cover(cover_id: str):
              params = auth_params()

              response = requests.get(
                  f"{NAVIDROME_URL}/rest/getCoverArt.view",
                  params={
                      **params,
                      "id": cover_id,
                  },
                  timeout=10,
              )

              return Response(
                  content=response.content,
                  media_type=response.headers.get(
                      "content-type",
                      "image/jpeg",
                  ),
                  headers={
                      "Cache-Control": "public, max-age=3600"
                  },
              )
        '';

      pythonEnv = pkgs.python3.withPackages (
        ps:
          with ps; [
            fastapi
            uvicorn
            requests
          ]
      );
    in {
      description = "Now Playing API";

      wantedBy = ["multi-user.target"];

      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "simple";

        DynamicUser = true;

        User = cfg.user;
        Group = cfg.user;

        ExecStart = ''
          ${pythonEnv}/bin/uvicorn \
            --host ${cfg.host} \
            --port ${toString cfg.port} \
            --workers 1 \
            app:app
        '';

        WorkingDirectory = pkgs.runCommand "now-playing-app" {} ''
          mkdir -p $out
          cp ${app} $out/app.py
        '';

        Restart = "always";
        RestartSec = 5;

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
      };
    };
  };
}
