{
  lib,
  buildNpmPackage,
  python3,
  python3Packages,
  dockerTools,
  cacert,
  tzdata,
  iana-etc,
  writeShellScript,
  bash,
  coreutils,
  ...
}: let
  version = "0.1.0";

  # ---- Frontend: SvelteKit static build ----
  frontend = buildNpmPackage {
    pname = "harvest-frontend";
    inherit version;
    src = ./frontend;

    # Run `npm install` inside ./frontend once to generate package-lock.json,
    # then update this hash with the value Nix prints on first build.
    npmDepsHash = "sha256-gH35kRSz1Rvu5cmnBWDffUa4ppMf61emU89kzrZyb3g=";

    # SvelteKit's adapter-static writes to `build/`.
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r build/* $out/
      runHook postInstall
    '';

    dontNpmPrune = true;
  };

  # ---- Backend: FastAPI app + deps from nixpkgs ----
  pythonEnv = python3.withPackages (ps:
    with ps; [
      fastapi
      uvicorn
      httpx
      pydantic
      pyyaml
    ]);

  backend = python3Packages.buildPythonApplication {
    pname = "harvest-backend";
    inherit version;
    src = ./backend;
    pyproject = true;
    nativeBuildInputs = [python3Packages.setuptools];
    propagatedBuildInputs = with python3Packages; [
      fastapi
      uvicorn
      httpx
      pydantic
      pyyaml
    ];
    doCheck = false;
  };

  # ---- Entrypoint script for the container ----
  entrypoint = writeShellScript "harvest-entrypoint" ''
    set -euo pipefail
    export HARVEST_STATIC_DIR=/app/static
    export HARVEST_VERSION=${version}
    exec ${pythonEnv}/bin/uvicorn app.main:app \
      --host "''${HARVEST_HOST:-0.0.0.0}" \
      --port "''${HARVEST_PORT:-9765}" \
      --no-access-log
  '';

  # ---- OCI image ----
  image = dockerTools.buildLayeredImage {
    name = "harvest";
    tag = version;

    contents = [
      pythonEnv
      backend
      bash
      coreutils
      cacert
      tzdata
      iana-etc
    ];

    extraCommands = ''
      mkdir -p app/static
      cp -r ${frontend}/. app/static/
      mkdir -p tmp inbox downloads data
    '';

    config = {
      Entrypoint = ["${entrypoint}"];
      WorkingDir = "/";
      Env = [
        "PYTHONPATH=${backend}/${python3.sitePackages}"
        "PYTHONDONTWRITEBYTECODE=1"
        "PYTHONUNBUFFERED=1"
        "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
        "TZ=Europe/Berlin"
        "HARVEST_STATIC_DIR=/app/static"
        "HARVEST_VERSION=${version}"
      ];
      ExposedPorts = {
        "9765/tcp" = {};
      };
    };
  };
in {
  inherit frontend backend image;
  inherit version;
}
