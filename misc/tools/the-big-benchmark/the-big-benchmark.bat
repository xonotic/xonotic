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
set xonotic=xonotic-x64.exe
goto postarg
:bit32
set xonotic=xonotic.exe
goto postarg
:postarg

if exist data\the-big-benchmark.log del data\the-big-benchmark.log
if exist data\benchmark.log del data\benchmark.log
if exist data\engine.log del data\engine.log
set p=+developer 1 -nohome -benchmarkruns 4 -benchmarkruns_skipfirst -benchmark demos/the-big-keybench.dem

if exist data\benchmark.log del data\benchmark.log
echo + %xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-omg.cfg %p% > data\engine.log
%xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-omg.cfg %p% >> data\engine.log 2>&1
find "]quit" data\engine.log >nul
if not errorlevel 1 goto done
type data\engine.log >> data\the-big-benchmark.log
type data\benchmark.log >> data\the-big-benchmark.log

if exist data\benchmark.log del data\benchmark.log
echo + %xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-low.cfg %p% > data\engine.log
%xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-low.cfg %p% >> data\engine.log 2>&1
find "]quit" data\engine.log >nul
if not errorlevel 1 goto done
type data\engine.log >> data\the-big-benchmark.log
type data\benchmark.log >> data\the-big-benchmark.log

if exist data\benchmark.log del data\benchmark.log
echo + %xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-med.cfg %p% > data\engine.log
%xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-med.cfg %p% >> data\engine.log 2>&1
find "]quit" data\engine.log >nul
if not errorlevel 1 goto done
type data\engine.log >> data\the-big-benchmark.log
type data\benchmark.log >> data\the-big-benchmark.log

if exist data\benchmark.log del data\benchmark.log
echo + %xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-normal.cfg %p% > data\engine.log
%xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-normal.cfg %p% >> data\engine.log 2>&1
find "]quit" data\engine.log >nul
if not errorlevel 1 goto done
type data\engine.log >> data\the-big-benchmark.log
type data\benchmark.log >> data\the-big-benchmark.log

if exist data\benchmark.log del data\benchmark.log
echo + %xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-high.cfg %p% > data\engine.log
%xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-high.cfg %p% >> data\engine.log 2>&1
find "]quit" data\engine.log >nul
if not errorlevel 1 goto done
type data\engine.log >> data\the-big-benchmark.log
type data\benchmark.log >> data\the-big-benchmark.log

if exist data\benchmark.log del data\benchmark.log
echo + %xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-ultra.cfg %p% > data\engine.log
%xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-ultra.cfg %p% >> data\engine.log 2>&1
find "]quit" data\engine.log >nul
if not errorlevel 1 goto done
type data\engine.log >> data\the-big-benchmark.log
type data\benchmark.log >> data\the-big-benchmark.log

if exist data\benchmark.log del data\benchmark.log
echo + %xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-ultimate.cfg %p% > data\engine.log
%xonotic% %2 %3 %4 %5 %6 %7 %8 %9 +exec effects-ultimate.cfg %p% >> data\engine.log 2>&1
find "]quit" data\engine.log >nul
if not errorlevel 1 goto done
type data\engine.log >> data\the-big-benchmark.log
type data\benchmark.log >> data\the-big-benchmark.log

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
