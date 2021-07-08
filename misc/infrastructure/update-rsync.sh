#!/bin/sh

set -ex

d=$1

cd /var/rsync/autobuild

for BUILD in '' -high -mappingsupport; do
	rm -rf .new
	mkdir .new
	cd .new
	if ! unzip ~/Xonotic-"$d$BUILD".zip; then
		good=false
		#for f in ~/Xonotic-"$d$BUILD".zip; do
		#	unzip "$f" && good=true && break
		#done
		$good
	fi
	cd Xonotic/data
	for X in *"$d"*; do
		pre=${X%$d*}
		post=${X##*$d}
		mv "$X" "$pre"rsync"$post"
	done
	cd ../../..
	rm -rf Xonotic.old
	mv Xonotic"$BUILD" Xonotic.old || true
	mv .new/Xonotic Xonotic"$BUILD"
	rmdir .new
	rm -rf Xonotic.old
done
