# Users and groups for music services
_: {
  users = {
    groups = {
      music = {};
      navidrome = {};
      music-tagger = {};
    };
    users = {
      daniel = {
        extraGroups = ["music"];
        homeMode = "0711";
      };
      navidrome = {
        extraGroups = ["music"];
        isSystemUser = true;
        group = "navidrome";
      };
      music-tagger = {
        extraGroups = ["music" "users"];
        isSystemUser = true;
        group = "music-tagger";
      };
    };
  };
}
