#!/bin/sh

set -e

if [ -d "${0%/*}" ]; then
	cd "${0%/*}"
fi
cd ../../..

echo "The Big Benchmark"
echo " ================="
echo
if [ -f ./all ]; then
	echo "WARNING: running this script will destroy ANY local changes you"
	echo "might have on the repository that haven't been pushed or stored"
	echo "in a local branch yet."
	echo
	if [ x"$1" != x"--yes" ]; then
		echo "Are you absolutely sure you want to run this?"
		echo
		while :; do
			echo -n "y/n: "
			read -r yesno
			case "$yesno" in
				y)
					break
					;;
				n)
					echo "Aborted."
					exit 1
					;;
			esac
		done
	fi
fi

if [ -f ./all ]; then
	./all clean -fU -m -r
	./all compile -r
	export USE_GDB=no
	set -- ./all run "$@"
elif [ -z "$*" ]; then
	case "`uname`" in
		Darwin)
			set -- ./Xonotic.app/Contents/MacOS/xonotic-osx-sdl
			;;
		Linux)
			set -- ./xonotic-linux-sdl.sh
			;;
		*)
			echo "OS not detected. Usage:"
			echo "  $0 how-to-run-xonotic"
			echo "On Windows when using a release build or an autobuild,"
			echo "use the-big-benchmark.bat instead!"
			exit 1
			;;
	esac
fi
rm -f data/the-big-benchmark.log
rm -f data/benchmark.log
rm -f data/engine.log
p="+r_texture_dds_load 1 +cl_playerdetailreduction 0 +developer 1 -nohome -benchmarkruns 4 -benchmarkruns_skipfirst -benchmark demos/the-big-keybench.dem"
for e in omg low med normal high ultra ultimate; do
	rm -f data/benchmark.log
	echo + "$@" +exec effects-$e.cfg $p > data/engine.log
	"$@" +exec effects-$e.cfg $p >>data/engine.log 2>&1 || true
	if grep '\]quit' data/engine.log >/dev/null; then
		break
	fi
	cat data/engine.log >> data/the-big-benchmark.log
	cat data/benchmark.log >> data/the-big-benchmark.log
done
if [ -f ./all ]; then
	./all clean -r
fi

rm -f data/benchmark.log
rm -f data/engine.log
if ! [ -f data/the-big-benchmark.log ]; then
	echo
	echo "The benchmark has been aborted. No log file has been written."
	exit
fi

echo
echo "Please provide the the following info to the Xonotic developers:"
echo " - CPU speed"
echo " - memory size"
echo " - graphics card (which vendor, which model)"
echo " - operating system (including whether it is 32bit or 64bit)"
echo " - graphics driver version"
echo " - the file the-big-benchmark.log in the data directory"
echo
echo "Thank you"
