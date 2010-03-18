#!/bin/sh

set -e

repos="
	data/xonotic-data.pk3dir
	data/xonotic-maps.pk3dir
	data/xonotic-music.pk3dir
	darkplaces
"

base=`git config remote.origin.url`
base=${base%/xonotic.git}
d0=`pwd`
for d in $repos; do
	if [ -d "$d0/$d" ]; then
		cd "$d0/$d"
		git config remote.origin.url "$base/${d##*/}.git"
		git pull
		cd "$d0"
	else
		git clone "$base/${d##*/}.git" "$d0/$d"
	fi
done
