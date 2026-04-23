{
  lib,
  python3,
  playwright-driver,
  src,
}:
python3.pkgs.buildPythonApplication {
  pname = "music-tagger";
  version = "0-unstable-2025-04-23";
  pyproject = false;

  inherit src;

  dependencies = with python3.pkgs; [
    flask
    mutagen
    requests
    musicbrainzngs
    python-dotenv
    pillow
    beautifulsoup4
    cryptography
    flask-wtf
    flask-limiter
    werkzeug
    playwright
  ];

  # No setup.py / pyproject.toml — install files manually
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/music-tagger
    cp -r . $out/lib/music-tagger/

    mkdir -p $out/bin
    cat > $out/bin/music-tagger <<EOF
    #!${python3}/bin/python3
    import sys, os
    os.chdir("$out/lib/music-tagger")
    sys.path.insert(0, "$out/lib/music-tagger")
    # Inject playwright browser path
    os.environ.setdefault("PLAYWRIGHT_BROWSERS_PATH", "${playwright-driver.browsers}")
    import app
    app.app.run(host="0.0.0.0", port=8099)
    EOF
    chmod +x $out/bin/music-tagger

    runHook postInstall
  '';

  # Point playwright at the nixpkgs-managed Chromium
  makeWrapperArgs = [
    "--set PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers}"
    "--set PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD 1"
  ];

  meta = {
    description = "NaviCura — Flask web app for managing and tagging local music collections";
    homepage = "https://github.com/iLazlow/music-tagger";
    license = lib.licenses.unfree;
    mainProgram = "music-tagger";
    platforms = lib.platforms.linux;
  };
}
