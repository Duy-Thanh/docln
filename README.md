# docln

Light Novel Reader written in Flutter (for Android, Windows and Linux)

iOS build officially released in release: **release_2025.05.01_02-32**! Check it out! 

# Bugs about corrupted preference file

On iOS build, when you open the WebView screen (press to item in Annoucement section),
no matter the WebView loaded the website succeeded or not, when restart application, 
the preference are corrupted.

To mitigate this bug, an backup/restore mechanism have implemented and available for both
Android and iOS. To use this feature, make sure you have latest version.

The backup preferences will be triggered every 6 hours, but remember to backup preferences
**regularly**. If your preferences broken, you can easily restore your preferences.

Remember to restart application after restore preferences to take effect!

## IMPORTANT NOTICE:

**UPDATE: After an break, I will continue developing this application, from now!**

**The Android build currently build supported, iOS build is in experimental. Stay tuned!**

**NOTE 2: The Android bundle build is currently not working. I am working on fixing it. Currently, only the APK build is working. The AAB build is disabled.**
