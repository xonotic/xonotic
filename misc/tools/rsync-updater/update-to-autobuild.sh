#!/bin/sh

cd "${0%/*}" || exit 1

[ -t 2 ] && [ -t 1 ] && [ -t 0 ] && interactive=true || interactive=false

if ! command -v rsync > /dev/null; then
	printf >&2 "\033[1;31mFATAL: rsync not found, please install the rsync package!\033[m\n"
	exit 1
fi

case "${0##*/}" in
	update-to-autobuild.sh)
		buildtype=autobuild
		;;
	*)
		buildtype=release
		;;
esac

# always use fuzzy (-y) because file names may differ (release->release, release<>autobuild)
# fuzzy requires --delete-delay or --delete-after
options="-Prtzilyhh --delete-excluded --stats"
if [ -n "$(rsync --help | sed -En 's/(--delete-delay)/\1/p')" ]; then
	options="$options --delete-delay" # more efficient, requires rsync 3.0.0 or later
else
	options="$options --delete-after"
fi
if [ "$OS" != "Windows_NT" ]; then
	options="$options --executability"
fi

package="Xonotic"
target="../../.."
if [ -d "../../../.git" ]; then
	printf >&2 "\033[1;33mNOTE: this is a git repository. Using the git update method.\033[m\n"
	exec ../../../all update
elif PWD="${PWD%/}" && [ "$PWD" != "${PWD%/misc/tools/rsync-updater}" ]; then
	if [ -f ../../../data/xonotic-*-data-high.pk3 ]; then
		echo "Found Xonotic-high data files"
		package="Xonotic-high"
	elif [ -f ../../../data/xonotic-*-data.pk3 ]; then
		echo "Found Xonotic data files"
	else
		printf "\033[1;31mNOTE: found misc/tools/rsync-updater parent directories but no data files!\033[m\n"
	fi
else
	printf >&2 "\033[1;31mFATAL: unrecognized Xonotic build. This update script cannot be used.\033[m\n"
	exit 1
fi
if [ -e "Xonotic" ]; then
	printf "\033[1;35mFound manually created 'Xonotic' package override\033[m\n"
	package="Xonotic"
elif [ -e "Xonotic-high" ]; then
	printf "\033[1;35mFound manually created 'Xonotic-high' package override\033[m\n"
	package="Xonotic-high"
fi
url="beta.xonotic.org/$buildtype-$package"

excludes=
if [ -n "$XONOTIC_INCLUDE_ALL" ]; then
	: noot noot
elif [ "$OS" = "Windows_NT" ]; then
	excludes="$excludes --exclude=/xonotic-linux*"
	excludes="$excludes --exclude=/xonotic-osx-*"
	excludes="$excludes --exclude=/Xonotic*.app"
	excludes="$excludes --exclude=/gmqcc/gmqcc.linux*"
	excludes="$excludes --exclude=/gmqcc/gmqcc.osx"

	if [ "$PROCESSOR_ARCHITECTURE" = AMD64 ]; then
		if [ -z "$XONOTIC_INCLUDE_32BIT" ]; then
		excludes="$excludes --exclude=/xonotic-x86.exe"
		excludes="$excludes --exclude=/xonotic-x86-dedicated.exe"
		excludes="$excludes --exclude=/xonotic-x86-wgl.exe"
		excludes="$excludes --exclude=/bin32"
		fi
	else
		excludes="$excludes --exclude=/xonotic.exe"
		excludes="$excludes --exclude=/xonotic-dedicated.exe"
		excludes="$excludes --exclude=/xonotic-wgl.exe"
		excludes="$excludes --exclude=/bin64"
	fi
else
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
			printf >&2 "\033[1;31m"
			printf >&2 "WARNING: Could not detect architecture\n"
			printf >&2 "WARNING: Xonotic does NOT provide pre-built %s executables\n" "$(uname):$(uname -m)"
			printf >&2 "WARNING: Please run make. More info is available at\n"
			printf >&2 "WARNING: \033[1;36mhttps://gitlab.com/xonotic/xonotic/-/wikis/Compiling\033[m\n"
			excludes="$excludes --exclude=/Xonotic*.app"
			excludes="$excludes --exclude=/xonotic-osx-*"
			excludes="$excludes --exclude=/xonotic-linux64-*"
			;;
	esac
fi

resolvedtarget=$(cd $target && [ "${PWD#$HOME}" != "$PWD" ] && printf "~${PWD#$HOME}" || printf "$PWD")
printf "Updating \033[1;34m$resolvedtarget\033[m from \033[0;36m$url \033[m...\n"

targetname=$(cd "$target" && printf "${PWD##*/}")
if [ "$1" = "-y" ] || [ "$1" = "--yes" ]; then
	choice=y
elif [ $interactive = false ]; then
	printf >&2 "\033[1;31mFATAL: non-interactive mode requires the \033[1;37m--yes\033[1;31m argument to acknowledge that this will DELETE any custom files in the \"$targetname\" directory.\033[m\n"
	exit 1
fi
until [ "$choice" = y ] || [ "$choice" = Y ]; do
	printf "\033[1mThis will DELETE any custom files in the \"$targetname\" folder, continue? [Y/N] \033[m"
	read -r choice
	[ "$choice" = n ] || [ "$choice" = N ] && exit 1
done

# exec ensures this script stops before it's updated to prevent potential glitches
exec rsync $options $excludes "rsync://$url/" "$target"
