#!/bin/sh

if ! which rsync >/dev/null; then
	echo >&2 "FATAL: rsync not found, please install the rsync package"
	exit 1
fi

options="-Prtzil --executability --delete-after --delete-excluded --stats"

if [ -d "Xonotic-low" ]; then
	url="rsync://beta.xonotic.org/autobuild-Xonotic-low/"
	target="Xonotic-low/"
elif [ -d "Xonotic-high" ]; then
	url="rsync://beta.xonotic.org/autobuild-Xonotic-high/"
	target="Xonotic-high/"
elif [ -d "../../../.git" ]; then
	echo >&2 "NOTE: this is a git repository download. Using the regular update method."
	exec ../../../all update
elif [ -d "../../../data" ]; then
	if [ -f ../../../data/xonotic-rsync-data-low.pk3 ]; then
		url="rsync://beta.xonotic.org/autobuild-Xonotic-low/"
	elif [ -f ../../../data/xonotic-*-data-low.pk3 ]; then
		url="rsync://beta.xonotic.org/autobuild-Xonotic-low/"
		options="$options -y" # use fuzzy matching because file names differ
	elif [ -f ../../../data/xonotic-rsync-data-high.pk3 ]; then
		url="rsync://beta.xonotic.org/autobuild-Xonotic-high/"
	elif [ -f ../../../data/xonotic-*-data-high.pk3 ]; then
		url="rsync://beta.xonotic.org/autobuild-Xonotic-high/"
		options="$options -y" # use fuzzy matching because file names differ
	elif [ -f ../../../data/xonotic-rsync-data.pk3 ]; then
		url="rsync://beta.xonotic.org/autobuild-Xonotic/"
	elif [ -f ../../../data/xonotic-*-data.pk3 ]; then
		url="rsync://beta.xonotic.org/autobuild-Xonotic/"
		options="$options -y" # use fuzzy matching because file names differ
	else
		echo >&2 "FATAL: unrecognized Xonotic build. This update script cannot be used."
		exit 1
	fi
	target="../../.."
else
	url="rsync://beta.xonotic.org/autobuild-Xonotic/"
	target="Xonotic/"
fi

excludes=
excludes="$excludes --exclude=/*.exe"
excludes="$excludes --exclude=/fteqcc/*.exe"
excludes="$excludes --exclude=/bin32"
excludes="$excludes --exclude=/*.dll"
excludes="$excludes --exclude=/bin64"

case `uname`:`uname -m` in
	Darwin:*)
		excludes="$excludes --exclude=/xonotic-linux*"
		excludes="$excludes --exclude=/fteqcc/fteqcc.linux*"
		;;
	Linux:x86_64)
		excludes="$excludes --exclude=/Xonotic*.app"
		excludes="$excludes --exclude=/xonotic-osx-*"
		excludes="$excludes --exclude=/fteqcc/fteqcc.osx"
		excludes="$excludes --exclude=/xonotic-linux32-*"
		excludes="$excludes --exclude=/fteqcc/fteqcc.linux32"
		;;
	Linux:i?86)
		excludes="$excludes --exclude=/Xonotic*.app"
		excludes="$excludes --exclude=/xonotic-osx-*"
		excludes="$excludes --exclude=/fteqcc/fteqcc.osx"
		excludes="$excludes --exclude=/xonotic-linux64-*"
		excludes="$excludes --exclude=/fteqcc/fteqcc.linux64"
		;;
	*)
		echo >&2 "WARNING: Could not detect architecture - downloading all architectures"
		;;
esac

rsync $options $excludes "$url" "$target"
