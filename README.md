# docln

Light Novel Reader written in Flutter (for Android, Windows and Linux)

iOS build officially released in release: **release_2025.05.01_02-32**! Check it out! 

# App Update Policy (Updated 05/20/2025):

The app is now in a **stable for daily use** state, so the update cycle will change.

Previously, because the app was in a heavy development state, the number of builds released in a day could be up to 5 releases in a day. However, because the app is in a stable state, the update and source code release cycle, from 05/20/2025, will be 2 weeks one release.

# Bugs about corrupted preference file

**UPDATE**: This issue have addressed. Please make sure that you have updated to the latest version

**Details problem:** On iOS build, when you open the WebView screen (press to item in Annoucement section),
no matter the WebView loaded the website succeeded or not, when restart application, 
the preference are corrupted.

To mitigate this bug, an backup/restore mechanism have implemented and available for both
Android and iOS. To use this feature, make sure you have latest version.

The backup preferences will be triggered every 6 hours, but remember to backup preferences
**regularly**. If your preferences broken, you can easily restore your preferences.

Remember to restart application after restore preferences to take effect!

## IMPORTANT NOTICE:

**UPDATE: After an break, I will continue developing this application, from now!**

**NOTE 2: The Android bundle build is currently not working. I am working on fixing it. Currently, only the APK build is working. The AAB build is disabled.**
