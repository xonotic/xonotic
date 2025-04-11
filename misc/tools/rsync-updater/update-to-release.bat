@echo off
setlocal

if "%did_copy%" == "true" goto copied
cd %~dp0
:: Windows can't update .exe and .dll files while they're running,
:: it can update the .bat file but that can cause execution glitches.
:: Shell scripts can also glitch if updated while running
:: but can be protected, which update-to-autobuild.sh and rsync-ssl are.
rmdir /s /q %TEMP%\xonotic-rsync-updater  2>NUL
mkdir %TEMP%\xonotic-rsync-updater
copy /b %~nx0 %TEMP%\xonotic-rsync-updater\  >NUL
:: windows has no cp -r equivalent, this seems least-bad
robocopy usr %TEMP%\xonotic-rsync-updater\usr /e   >NUL
set did_copy=true
%TEMP%\xonotic-rsync-updater\%~n0 %*
:: can only get here if above batch file couldn't be created
pause
exit /b

:copied
set PATH=%TEMP%\xonotic-rsync-updater\usr\bin;%PATH%
:: $PATH $PWD $TEMP and $TMP get automatic cygwin path conversion but $0 doesn't,
:: sourcing the main script and setting a custom $0 also works around broken symlink support.
sh -c ". ./update-to-autobuild.sh" ./%~n0.sh %*

pause
:: hack: delete running batch file without error by deleting after batch exit
(goto) 2>NUL & rmdir /s /q %TEMP%\xonotic-rsync-updater
