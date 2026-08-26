{ user, pkgs, ... }:

let
  # Apps that donate content to Siri Suggestions / Spotlight Knowledge
  # (`defaults read com.apple.spotlightknowledge` lists the donation counts).
  # Blacklisting them is the "Learn from this application" and "Show Siri
  # Suggestions" toggles under Siri Suggestions & Privacy.
  siriApps = [
    "com.apple.MobileSMS"
    "com.apple.Notes"
    "com.apple.mail"
    "com.apple.shortcuts"
    "com.apple.helpviewer"
    "com.apple.podcasts"
    "com.apple.mobilephone"
    "com.apple.Safari"
    "com.apple.iCal"
    "com.apple.reminders"
    "com.apple.FaceTime"
    "com.apple.Photos"
  ];
in
{
  # Disable Siri, Siri Suggestions and Apple Intelligence.
  # spotlightknowledged/corespotlightd (the Core Spotlight knowledge index that
  # feeds Siri Suggestions and Apple Intelligence) cannot be stopped without
  # disabling SIP; the most we can do is cut off what feeds it.
  # References:
  # - https://discussions.apple.com/thread/254091262
  # - https://community.jamf.com/t5/jamf-pro/complete-siri-disabling-instructions-used-during-testing-edit-not/m-p/264667
  # - https://eclecticlight.co/2026/07/04/spotlight-and-core-spotlight-are-different/
  system.defaults.CustomUserPreferences = {
    "com.apple.assistant.support" = {
      "Assistant Enabled" = false;
      # 2 = opted out of sharing Siri and search data with Apple
      "Siri Data Sharing Opt-In Status" = 2;
    };
    "com.apple.Siri" = {
      StatusMenuVisible = false;
      UserHasDeclinedEnable = true;
      VoiceTriggerUserEnabled = false;
    };
    "com.apple.suggestions" = {
      SiriCanLearnFromAppBlacklist = siriApps;
      AppCanShowSiriSuggestionsBlacklist = siriApps;
    };
    "com.apple.CloudSubscriptionFeatures.optIn" = {
      auto_opt_in = false;
      opted_in_buddy = false;
    };
  };

  # Apple Intelligence is opted in per Apple Account: the optIn plist holds one
  # key per account ID, so the ids cannot be listed statically. Flip every one.
  system.activationScripts.postActivation.text = ''
    echo "Opting out of Apple Intelligence..."
    optin="/Users/${user.username}/Library/Preferences/com.apple.CloudSubscriptionFeatures.optIn.plist"
    if [ -f "$optin" ]; then
      for key in $(/usr/bin/plutil -convert json -o - "$optin" | ${pkgs.jq}/bin/jq -r 'keys[]'); do
        case "$key" in
          auto_opt_in|opted_in_buddy) ;;
          *) sudo -u ${user.username} /usr/bin/defaults write com.apple.CloudSubscriptionFeatures.optIn "$key" -bool false ;;
        esac
      done
    fi
  '';
}
