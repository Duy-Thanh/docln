@echo off
set /p msg=Enter your commit message: 
git add .
git commit -m "%msg%"
git push
pause
