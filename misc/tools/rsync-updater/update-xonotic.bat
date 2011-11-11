@echo off

set options=-Prtzil --executability --delete-after --delete-excluded --stats

if exist Xonotic-low goto xonoticlow
if exist Xonotic-high goto xonotichigh
goto xonotic
:xonoticlow
set url=rsync://beta.xonotic.org/autobuild-Xonotic-low/
set target=Xonotic-low/
goto endxonotic
:xonotichigh
set url=rsync://beta.xonotic.org/autobuild-Xonotic-high/
set target=Xonotic-high/
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
pause
