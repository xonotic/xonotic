#!/bin/sh

set -e

case "$1" in
	local)
		base=ssh://gitolite
		;;
	ssh)
		base=ssh://xonotic@git.xonotic.org
		;;
	git)
		base=git://git.xonotic.org/xonotic
		;;
	http)
		base=http://git.xonotic.org/~xonotic
		;;
	*)
		echo "Usage: $0 transport, where transport might be local, ssh, git or http"
		exit 1
		;;
esac

mkdir -p data
git clone "$base/xonotic-data.pk3dir" data/xonotic-data.pk3dir
git clone "$base/xonotic-maps.pk3dir" data/xonotic-maps.pk3dir
git clone "$base/xonotic-music.pk3dir" data/xonotic-music.pk3dir
