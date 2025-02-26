#!/bin/sh

cd "${0%/*}" || exit 1

if ! which rsync > /dev/null; then
	printf >&2 "\n\e[1;31mFATAL: rsync not found, please install the rsync package!\e[m\n"
	exit 1
fi
if which rsync-ssl > /dev/null; then
	cmd=rsync-ssl
else
	printf >&2 "\n\e[1;33mWARNING: rsync-ssl not found, connection will be insecure!\e[m\n"
	cmd=rsync
fi

if [ "$1" = "-y" ] || [ "$1" = "--yes" ]; then
	choice=y
fi
until [ "$choice" = y ] || [ "$choice" = Y ]; do
	printf "\e[1mThis script will DELETE any custom files in the Xonotic folder. Do you want to continue [Y/N]? \e[m"
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

# use fuzzy matching because file names may differ (release->release, release<>autobuild)
options="-Prtzily --executability --delete-after --delete-excluded --stats"

package="Xonotic"
target="../../.."
if [ -d "../../../.git" ]; then
	printf >&2 "\e[1;33mNOTE: this is a git repository. Using the git update method.\e[m\n"
	exec ../../../all update
elif [ -e "Xonotic" ]; then
	printf "\e[1mfound manually created 'Xonotic' file\e[m"
elif [ -e "Xonotic-high" ]; then
	printf "\e[1mfound manually created 'Xonotic-high' file\e[m"
	package="Xonotic-high"
elif [ -d "../../../data" ]; then
	if [ -f ../../../data/xonotic-rsync-data-high.pk3 ]; then
		echo "found beta autobuild Xonotic-high files"
		package="Xonotic-high"
	elif [ -f ../../../data/xonotic-*-data-high.pk3 ]; then
		echo "found stable release Xonotic-high files"
		package="Xonotic-high"
	elif [ -f ../../../data/xonotic-rsync-data.pk3 ]; then
		echo "found beta autobuild Xonotic files"
	elif [ -f ../../../data/xonotic-*-data.pk3 ]; then
		echo "found stable release Xonotic files"
	else
		printf >&2 "\n\e[1;31mFATAL: unrecognized Xonotic build. This update script cannot be used.\e[m\n"
		exit 1
	fi
else
	target="Xonotic/"
fi
url="rsync.xonotic.org/$buildtype/$package/"

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

echo "Syncing $(cd $target && printf $PWD/) with $url ..."
$cmd $options $excludes "rsync://$url" "$target"
