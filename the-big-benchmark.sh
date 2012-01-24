#!/bin/sh

set -e

echo "The Big Benchmark"
echo " ================="
echo
echo "WARNING: running this script will destroy ANY local changes you"
echo "might have on the repository."
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

set -x
rm -f data/*.log
./all clean --reclone
./all compile -r
(
	set -x
	for e in omg low med normal high ultra ultimate; do
		USE_GDB=no \
		./all run \
			+exec effects-$e.cfg \
			"$@" \
			-nohome \
			-benchmarkruns 4 -benchmarkruns_skipfirst \
			-benchmark demos/the-big-keybench.dem
	done
) >data/engine.log 2>&1
./all clean -r -f -u
set +x

echo
echo "Please provide the the following info to the Xonotic developers:"
echo " - CPU speed"
echo " - memory size"
echo " - graphics card (which vendor, which model)"
echo " - operating system (including whether it is 32bit or 64bit)"
echo " - graphics driver version"
echo " - the file "
cat data/benchmark.log
echo
echo "Thank you"
