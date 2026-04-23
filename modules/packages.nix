{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages = {
      music-tagger = pkgs.callPackage ../pkgs/music-tagger {
        inherit (pkgs) playwright-driver;
        src = inputs.music-tagger;
      };
    };
  };
}
