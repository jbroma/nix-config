{ ... }:

{
  # Disable Siri
  # References:
  # - https://discussions.apple.com/thread/254091262
  # - https://community.jamf.com/t5/jamf-pro/complete-siri-disabling-instructions-used-during-testing-edit-not/m-p/264667
  system.defaults.CustomUserPreferences = {
    "com.apple.assistant.support" = {
      "Assistant Enabled" = false;
    };
    "com.apple.Siri" = {
      StatusMenuVisible = false;
      UserHasDeclinedEnable = true;
      VoiceTriggerUserEnabled = false;
    };
  };
}
