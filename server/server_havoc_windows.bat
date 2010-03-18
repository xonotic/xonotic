@echo off

setlocal
set executable=nexuiz -dedicated

%~d0
cd "%~p0"

if exist %executable% goto good
if not exist ..\%executable% goto bad
if exist ..\data\server.cfg goto halfgood
if exist ..\havoc\server.cfg goto halfgood
goto bad

:bad
echo This script is not properly set up yet.
echo Please refer to the instructions in readme.txt.
echo In short:
echo - copy server.cfg to the data directory and adjust its settings
echo - move this file to the main directory of your Nexuiz installation
pause
exit

:halfgood
cd ..

:good
.\%executable% -game havoc +serverconfig server.cfg %*
