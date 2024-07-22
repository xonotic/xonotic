#!/bin/sh

# misc/tools/tag-release.sh

# bail when we aren't supposed to be making a release :)
[ "$REALLY_DO_IT" != "yes" ] && exit 2

case "$#" in
	1)
		VER=$1
		;;
	*)
		echo "Need version number as argument"
		exit 1
		;;
esac

set -eux



# find xonotic/xonotic.git root repo
ROOTREPO="$(realpath "$(dirname misc/tools/tag-release.sh)/../../")"
cd "$ROOTREPO"
git pull
./all checkout
./all update



for r in \
	"$ROOTREPO" \
	"$ROOTREPO/data/xonotic-data.pk3dir" \
	"$ROOTREPO/data/xonotic-music.pk3dir" \
	"$ROOTREPO/data/xonotic-nexcompat.pk3dir" \
	"$ROOTREPO/data/xonotic-xoncompat.pk3dir" \
	"$ROOTREPO/darkplaces" \
	"$ROOTREPO/d0_blind_id" \
	"$ROOTREPO/data/xonotic-maps.pk3dir" \
	"$ROOTREPO/mediasource" \
	"$ROOTREPO/gmqcc"
# excluded repos because not included with releases:
	#"$ROOTREPO/netradiant"
	#"$ROOTREPO/div0-gittools"
do
	cd "$r"

	git tag --sign --message="version $VER" "xonotic-v$VER"
	git push origin "xonotic-v$VER"
done
