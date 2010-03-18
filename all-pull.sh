#!/bin/sh

set -ex
git pull
for x in "`pwd`/data"/*.pk3dir/.git; do
	cd "${x%/.git}"
	git pull
done
