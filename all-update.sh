#!/bin/sh

set -e

base=`git config remote.origin.url`
base=${base%/xonotic.git}
d0=`pwd`/data
for d in data maps music; do
	dd="xonotic-$d.pk3dir"
	if [ -d "$d0/$dd" ]; then
		cd "$d0/$dd"
		git config remote.origin.url "$base/$dd.git"
		git pull
		cd "$d0"
	else
		git clone "$base/$dd.git" "$d0/dd"
	fi
done
