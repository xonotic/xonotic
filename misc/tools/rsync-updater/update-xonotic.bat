@echo off

set options=-Prtzil --executability --delete-after --delete-excluded --stats

if exist Xonotic-low goto xonoticlow
if exist Xonotic-high goto xonotichigh
if exist ..\..\..\.git goto xonoticdatagit
if exist ..\..\..\data goto xonoticdata
goto xonotic
:xonoticlow
	set url=rsync://beta.xonotic.org/autobuild-Xonotic-low/
	set target=Xonotic-low/
	goto endxonotic
:xonotichigh
	set url=rsync://beta.xonotic.org/autobuild-Xonotic-high/
	set target=Xonotic-high/
	goto endxonotic
:xonoticdatagit
	echo NOTE: this is a git repository download. Using the regular update method.
	..\..\..\all update
	goto end
:xonoticdata
	if exist ..\..\..\misc\tools\rsync-updater\rsync.exe goto xonoticdatarsync
	echo FATAL: rsync not in misc\tools\rsync-updater. This update script cannot be used.
	goto end
:xonoticdatarsync
	set PATH=misc\tools\rsync-updater;%PATH%
	cd ..\..\..
	if exist data\xonotic-rsync-data-low.pk3 goto xonoticdatalow
	if exist data\xonotic-*-data-low.pk3 goto xonoticdatalowfuzzy
	if exist data\xonotic-rsync-data-high.pk3 goto xonoticdatahigh
	if exist data\xonotic-*-data-high.pk3 goto xonoticdatahighfuzzy
	if exist data\xonotic-rsync-data.pk3 goto xonoticdatanormal
	if exist data\xonotic-*-data.pk3 goto xonoticdatanormalfuzzy
	echo FATAL: unrecognized Xonotic build. This update script cannot be used.
	goto end
:xonoticdatalow
		set url=rsync://beta.xonotic.org/autobuild-Xonotic-low/
		goto endxonoticdata
:xonoticdatalowfuzzy
		set url=rsync://beta.xonotic.org/autobuild-Xonotic-low/
		set options=%options% -y
		goto endxonoticdata
:xonoticdatahigh
		set url=rsync://beta.xonotic.org/autobuild-Xonotic-high/
		goto endxonoticdata
:xonoticdatahighfuzzy
		set url=rsync://beta.xonotic.org/autobuild-Xonotic-high/
		set options=%options% -y
		goto endxonoticdata
:xonoticdatanormal
		set url=rsync://beta.xonotic.org/autobuild-Xonotic/
		goto endxonoticdata
:xonoticdatanormalfuzzy
		set url=rsync://beta.xonotic.org/autobuild-Xonotic/
		set options=%options% -y
		goto endxonoticdata
:endxonoticdata
	set target=./
	goto endxonotic
:xonotic
	set url=rsync://beta.xonotic.org/autobuild-Xonotic/
	set target=Xonotic/
	goto endxonotic
:endxonotic

set excludes=
set excludes=%excludes% --exclude=/xonotic-linux*
set excludes=%excludes% --exclude=/xonotic-osx-*
set excludes=%excludes% --exclude=/Xonotic*.app
set excludes=%excludes% --exclude=/fteqcc/fteqcc.linux*
set excludes=%excludes% --exclude=/fteqcc/fteqcc.osx

if "%ProgramFiles(x86)%" == "" goto bit32
:bit64
	set excludes=%excludes% --exclude=/xonotic.exe
	set excludes=%excludes% --exclude=/xonotic-sdl.exe
	set excludes=%excludes% --exclude=/xonotic-dedicated.exe
	set excludes=%excludes% --exclude=/fteqcc/fteqcc.exe
	set excludes=%excludes% --exclude=/bin32
	set excludes=%excludes% --exclude=/*.dll
	goto endbit
:bit32
	set excludes=%excludes% --exclude=/xonotic-x64.exe
	set excludes=%excludes% --exclude=/xonotic-x64-sdl.exe
	set excludes=%excludes% --exclude=/xonotic-x64-dedicated.exe
	set excludes=%excludes% --exclude=/fteqcc/fteqcc-x64.exe
	set excludes=%excludes% --exclude=/bin64
	goto endbit
:endbit

rsync %options% %excludes% %url% %target%
chmod -R a+x %target%

:end
pause
