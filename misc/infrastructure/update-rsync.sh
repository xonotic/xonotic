#!/bin/sh

set -x

d=$1

cd /var/rsync/autobuild

for BUILD in '' -low -lowdds; do
	mkdir .new
	cd .new
	unzip /var/www/autobuild/Xonotic-"$d$BUILD".zip
	cd Xonotic/data
	for X in *"$d"*; do
		pre=${X%$d*}
		post=${X##*$d}
		mv "$X" "$pre"rsync"$post"
	done
	cd ../../..
	mv Xonotic"$BUILD" Xonotic.old || true
	mv .new/Xonotic Xonotic"$BUILD"
	rmdir .new
	rm -rf Xonotic.old
done
