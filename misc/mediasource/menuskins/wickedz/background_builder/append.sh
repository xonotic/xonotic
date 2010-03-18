#!/bin/sh
#
# Created by Tyler "-z-" Mulligan to build the version number for Nexuiz
# in the menu.  Released under the GPLv2
#
# Usage: pass a string to be converted to an image
#
# ./append 2.5.1
#
# _ = space
# s = svn
# z = z0rz (just for fun :-P)

# build the image out of the string for the version
build_version()
{
	version=$1
	imagified=$(echo $version | sed 's/\(.\)/vfont_\1.tga /g' | sed 's/s/svn/g;s/_\./_dot/g;s/__/_nbsp/g;s/z/z0rz/g' )
	f=`mktemp`
	convert $imagified +append TGA:"$f"
	echo "$f"
}

# place the image string on the big image
place_on_bg()
{
	#convert background_25.tga -page +259+41 TGA:"$1" -flatten "$2"/background.tga
	#convert background_ingame_25.tga -page +259+41 TGA:"$1" -flatten "$2"/background_ingame.tga
	convert background_l2.tga -draw "image over 259,41 0,0 'TGA:$1'" "$2"/background_l2.tga
}

# test case
#build_version 2.4_sz

f=`build_version "$1"`
place_on_bg "$f" "$2"
rm -f "$f"
