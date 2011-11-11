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
