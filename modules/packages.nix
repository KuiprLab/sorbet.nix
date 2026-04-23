_: {
  perSystem = {pkgs, ...}: {
    packages = {
      music-tagger = pkgs.callPackage ../pkgs/music-tagger {
        playwright-driver = pkgs.playwright-driver;
      };
    };
  };
}
