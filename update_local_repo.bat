@echo off

echo Pulling latest changes from remote repository...
git pull

echo Getting latest dependencies...
flutter pub get

echo Done!