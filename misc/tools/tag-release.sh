#!/bin/sh

VER=$1

case "$VER" in
	'')
		echo "Need version number as argument"
		exit 1
		;;
	*)
		;;
esac

for r in \
	/home/rpolzer/Games/Xonotic/. \
	/home/rpolzer/Games/Xonotic/data/xonotic-data.pk3dir \
	/home/rpolzer/Games/Xonotic/data/xonotic-music.pk3dir \
	/home/rpolzer/Games/Xonotic/data/xonotic-nexcompat.pk3dir \
	/home/rpolzer/Games/Xonotic/darkplaces \
	/home/rpolzer/Games/Xonotic/d0_blind_id \
	/home/rpolzer/Games/Xonotic/data/xonotic-maps.pk3dir \
	/home/rpolzer/Games/Xonotic/mediasource \
	/home/rpolzer/Games/Xonotic/gmqcc
do
	cd "$r"
	git tag -u D276946B -m"version $VER" xonotic-v"$VER"
done

# excluded repos because not included with releases:
#	/home/rpolzer/Games/Xonotic/netradiant \
#	/home/rpolzer/Games/Xonotic/div0-gittools \
