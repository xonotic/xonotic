#!/bin/sh

cd "${0%/*}" || exit 1

if ! which rsync > /dev/null; then
	echo >&2 "FATAL: rsync not found, please install the rsync package"
	exit 1
fi

if [ "$1" = "-y" ] || [ "$1" = "--yes" ]; then
	choice=y
fi
until [ "$choice" = y ] || [ "$choice" = Y ]; do
	printf "This script will DELETE any custom files in the Xonotic folder. Do you want to continue [Y/N]? "
	read -r choice
	[ "$choice" = n ] || [ "$choice" = N ] && exit 1
done

case "${0##*/}" in
	update-to-autobuild.sh)
		buildtype=autobuild
		;;
	*)
		buildtype=release
		;;
esac

options="-Prtzil --executability --delete-after --delete-excluded --stats"

if [ -d "../../../.git" ]; then
	echo >&2 "NOTE: this is a git repository download. Using the regular update method."
	exec ../../../all update
elif [ -e "Xonotic" ]; then
	echo "found manually created 'Xonotic' file"
	echo "targetting the normal $buildtype version"
	url="rsync://beta.xonotic.org/$buildtype-Xonotic/"
	target="../../.."
	options="$options -y" # use fuzzy matching because file names may differ
elif [ -e "Xonotic-high" ]; then
	echo "found manually created 'Xonotic-high' file"
	echo "targetting the high $buildtype version"
	url="rsync://beta.xonotic.org/$buildtype-Xonotic-high/"
	target="../../.."
	options="$options -y" # use fuzzy matching because file names may differ
elif [ -d "../../../data" ]; then
	if [ -f ../../../data/xonotic-rsync-data-high.pk3 ]; then
		echo "found rsync high data files"
		echo "targetting the high $buildtype version"
		url="rsync://beta.xonotic.org/$buildtype-Xonotic-high/"
	elif [ -f ../../../data/xonotic-*-data-high.pk3 ]; then
		echo "found release high data files"
		echo "targetting the high $buildtype version"
		url="rsync://beta.xonotic.org/$buildtype-Xonotic-high/"
		options="$options -y" # use fuzzy matching because file names differ
	elif [ -f ../../../data/xonotic-rsync-data.pk3 ]; then
		echo "found Xonotic rsync data files"
		echo "targetting the normal $buildtype version"
		url="rsync://beta.xonotic.org/$buildtype-Xonotic/"
	elif [ -f ../../../data/xonotic-*-data.pk3 ]; then
		echo "found Xonotic release data files"
		echo "targetting the normal $buildtype version"
		url="rsync://beta.xonotic.org/$buildtype-Xonotic/"
		options="$options -y" # use fuzzy matching because file names differ
	else
		echo >&2 "FATAL: unrecognized Xonotic build. This update script cannot be used."
		exit 1
	fi
	target="../../.."
else
	url="rsync://beta.xonotic.org/$buildtype-Xonotic/"
	target="Xonotic/"
fi

excludes=
if [ -z "$XONOTIC_INCLUDE_ALL" ]; then
	excludes="$excludes --exclude=/*.exe"
	excludes="$excludes --exclude=/bin32"
	excludes="$excludes --exclude=/*.dll"
	excludes="$excludes --exclude=/bin64"

	case $(uname):$(uname -m) in
		Darwin:*)
			excludes="$excludes --exclude=/xonotic-linux*"
			;;
		Linux:x86_64)
			excludes="$excludes --exclude=/Xonotic*.app"
			excludes="$excludes --exclude=/xonotic-osx-*"
			;;
		*)
			printf >&2 "\e[1;31m"
			printf >&2 "WARNING: Could not detect architecture\n"
			printf >&2 "WARNING: Xonotic does NOT provide pre-built %s executables\n" "$(uname):$(uname -m)"
			printf >&2 "WARNING: Please run make. More info is available at\n"
			printf >&2 "WARNING: \e[1;36mhttps://gitlab.com/xonotic/xonotic/-/wikis/Compiling\e[m\n"
			excludes="$excludes --exclude=/Xonotic*.app"
			excludes="$excludes --exclude=/xonotic-osx-*"
			excludes="$excludes --exclude=/xonotic-linux64-*"
			;;
	esac
fi

rsync $options $excludes "$url" "$target"
