@echo off

if "%1" == "did-copy" goto copied
cd %~dp0
rmdir /s /q %TEMP%\xonotic-rsync-updater
mkdir %TEMP%\xonotic-rsync-updater
for %%f in (*.exe *.dll *.bat) do copy /b %%f %TEMP%\xonotic-rsync-updater\
%TEMP%\xonotic-rsync-updater\%~n0 did-copy
exit

:copied

set /p choice=This script will DELETE any custom files in the Xonotic folder. Do you want to continue [Y/N]?
if /i not "%choice%" == "Y" goto end

set buildtype=release
if "%~n0" == "update-to-autobuild" set buildtype=autobuild

set options=-Prtzil --executability --delete-after --delete-excluded --stats

if exist ..\..\..\.git goto xonoticdatagit
if exist ..\..\..\data goto xonoticdata
if exist Xonotic goto xonoticswitchtonormal
if exist Xonotic-high goto xonoticswitchtohigh
goto xonotic
:xonoticdatagit
	echo NOTE: this is a git repository download. Using the regular update method.
	..\..\..\all update
	goto end
:xonoticswitchtohigh
	set PATH=misc\tools\rsync-updater;%PATH%
	cd ..\..\..
	if exist misc\tools\rsync-updater\rsync.exe goto xonoticdatahighfuzzy
	echo FATAL: rsync not in misc\tools\rsync-updater. This update script cannot be used.
	goto end
:xonoticswitchtonormal
	set PATH=misc\tools\rsync-updater;%PATH%
	cd ..\..\..
	if exist misc\tools\rsync-updater\rsync.exe goto xonoticdatanormalfuzzy
	echo FATAL: rsync not in misc\tools\rsync-updater. This update script cannot be used.
	goto end
:xonoticdata
	if exist ..\..\..\misc\tools\rsync-updater\rsync.exe goto xonoticdatarsync
	echo FATAL: rsync not in misc\tools\rsync-updater. This update script cannot be used.
	goto end
:xonoticdatarsync
	set PATH=misc\tools\rsync-updater;%PATH%
	cd ..\..\..
	if exist data\xonotic-rsync-data-high.pk3 goto xonoticdatahigh
	if exist data\xonotic-*-data-high.pk3 goto xonoticdatahighfuzzy
	if exist data\xonotic-rsync-data.pk3 goto xonoticdatanormal
	if exist data\xonotic-*-data.pk3 goto xonoticdatanormalfuzzy
	echo FATAL: unrecognized Xonotic build. This update script cannot be used.
	goto end
:xonoticdatahigh
		set url=rsync://beta.xonotic.org/%buildtype%-Xonotic-high/
		goto endxonoticdata
:xonoticdatahighfuzzy
		set url=rsync://beta.xonotic.org/%buildtype%-Xonotic-high/
		set options=%options% -y
		goto endxonoticdata
:xonoticdatanormal
		set url=rsync://beta.xonotic.org/%buildtype%-Xonotic/
		goto endxonoticdata
:xonoticdatanormalfuzzy
		set url=rsync://beta.xonotic.org/%buildtype%-Xonotic/
		set options=%options% -y
		goto endxonoticdata
:endxonoticdata
	set target=./
	goto endxonotic
:xonotic
	set url=rsync://beta.xonotic.org/%buildtype%-Xonotic/
	set target=Xonotic/
	goto endxonotic
:endxonotic

set excludes=
if not "%XONOTIC_INCLUDE_ALL%" == "" goto endbit
set excludes=%excludes% --exclude=/xonotic-linux*
set excludes=%excludes% --exclude=/xonotic-osx-*
set excludes=%excludes% --exclude=/Xonotic*.app
set excludes=%excludes% --exclude=/gmqcc/gmqcc.linux*
set excludes=%excludes% --exclude=/gmqcc/gmqcc.osx

if "%ProgramFiles(x86)%" == "" goto bit32
:bit64
	if not "%XONOTIC_INCLUDE_32BIT%" == "" goto endbit
	set excludes=%excludes% --exclude=/xonotic-x86.exe
	set excludes=%excludes% --exclude=/xonotic-x86-dedicated.exe
	set excludes=%excludes% --exclude=/gmqcc/gmqcc.exe
	set excludes=%excludes% --exclude=/bin32
	set excludes=%excludes% --exclude=/*.dll
	goto endbit
:bit32
	set excludes=%excludes% --exclude=/xonotic.exe
	set excludes=%excludes% --exclude=/xonotic-dedicated.exe
	set excludes=%excludes% --exclude=/gmqcc/gmqcc-x64.exe
	set excludes=%excludes% --exclude=/bin64
	goto endbit
:endbit

for %%f in (*.exe *.dll) do copy /b %%f %TEMP%\xonotic-rsync-updater\
%TEMP%\xonotic-rsync-updater\rsync %options% %excludes% %url% %target%
%TEMP%\xonotic-rsync-updater\chmod -R a+x %target%

:end
pause
rmdir /s /q %TEMP%\xonotic-rsync-updater
