#!/bin/sh

set -ex
git pull
for x in "`pwd`/data"/*.pk3dir; do
	cd "$x"
	git pull
done
