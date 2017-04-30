@echo off

cd %~dp0
cd ..\..\..

echo The Big Benchmark
echo  =================
echo.
if not exist all goto nogit
echo For Git builds, please use the-big-benchmark.sh instead!
goto end
:nogit
if "%1" == "" goto noarg
set xonotic=%1
goto postarg
:noarg
if "%ProgramFiles(x86)%" == "" goto bit32
:bit64
set xonotic=xonotic.exe
goto postarg
:bit32
set xonotic=xonotic-x86.exe
goto postarg
:postarg

if exist data\the-big-benchmark.log del data\the-big-benchmark.log
if exist data\benchmark.log del data\benchmark.log
if exist data\engine.log del data\engine.log
set p=+vid_width 1024 +vid_height 768 +vid_desktopfullscreen 0 +cl_curl_enabled 0 +r_texture_dds_load 1 +cl_playerdetailreduction 0 +developer 1 -nohome -benchmarkruns 4 -benchmarkruns_skipfirst -benchmark demos/the-big-keybench.dem

goto start

:benchmark
echo Benchmarking on %e%
if exist data\benchmark.log del data\benchmark.log
echo + %xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-%e%.cfg %p% > data\engine.log
%xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-%e%.cfg %p% >> data\engine.log 2>&1
find "MED: " data\engine.log
find "]quit" data\engine.log >nul
if not errorlevel 1 goto done
type data\engine.log >> data\the-big-benchmark.log
type data\benchmark.log >> data\the-big-benchmark.log
if not "%e%" == "med" goto nomed
find "checking for OpenGL 2.0 core features...  not detected" data\engine.log >nul
if errorlevel 1 goto nomed
echo OpenGL 2.0 or later required for Normal quality and higher, exiting.
goto done
:nomed
if not "%e%" == "med" goto nomed2
find "Using GL1.3 rendering path" data\engine.log >nul
if errorlevel 1 goto nomed2
echo OpenGL 2.0 rendering disabled, exiting.
goto done
:nomed2
if not "%e%" == "high" goto nohigh
find "vid_soft 1" data\engine.log >nul
if errorlevel 1 goto nohigh
echo Software rendering does not support Ultra and Ultimate quality settings, exiting.
goto done
:nohigh
goto z%e%

:start

set e=omg
goto benchmark
:zomg

set e=low
goto benchmark
:zlow

set e=med
goto benchmark
:zmed

set e=normal
goto benchmark
:znormal

set e=high
goto benchmark
:zhigh

set e=ultra
goto benchmark
:zultra

set e=ultimate
goto benchmark
:zultimate

:done

if exist data\benchmark.log del data\benchmark.log
if exist data\engine.log del data\engine.log

if exist data\the-big-benchmark.log goto logisgood
echo.
echo The benchmark has been aborted. No log file has been written.
goto end

:logisgood
echo.
echo Please provide the the following info to the Xonotic developers:
echo  - CPU speed
echo  - memory size
echo  - graphics card (which vendor, which model)
echo  - operating system (including whether it is 32bit or 64bit)
echo  - graphics driver version
echo  - the file the-big-benchmark.log in the data directory
echo.
echo Thank you
:end
pause
