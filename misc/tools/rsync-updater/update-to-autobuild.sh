#!/bin/sh

cd "${0%/*}" || exit 1

[ -t 2 ] && [ -t 1 ] && [ -t 0 ] && interactive=true || interactive=false

if ! command -v rsync > /dev/null; then
	printf >&2 "\033[1;31mFATAL: rsync not found, please install the rsync package!\033[m\n"
	exit 1
fi

# always prefer our own rsync-ssl script, we need its --ipv4 and --ipv6 option support
export PATH="$PWD/usr/bin:$PATH"

# openssl is the only option, as gnutls-cli is broken in rsync-ssl and stunnel doesn't verify the cert.
rsynccmd="rsync-ssl --timeout=3"
if ! command -v openssl > /dev/null; then
	if [ $interactive = false ]; then
		printf >&2 "\033[1;31mFATAL: openssl not found, please install the openssl package!\033[m\n"
		exit 1
	fi
	printf "\033[1;33mWARNING: openssl not found, please install the openssl package!\033[m\n"
	unset secchoice # no automated skipping, this is important
	until [ "$secchoice" = y ] || [ "$secchoice" = Y ]; do
		printf "\033[1;33mConnecting without openssl is insecure, continue? [Y/N] \033[m"
		read -r secchoice
		[ "$secchoice" = n ] || [ "$secchoice" = N ] && exit 1
	done
	rsynccmd="rsync --contimeout=3"
fi

# scan cmdline args
for arg in "$@"; do
	[ "$arg" = "--yes" ] || [ "$arg" = "-y" ] && choice=y
	[ "$arg" = "--include-all" ] || [ "$arg" = "-a" ] && XONOTIC_INCLUDE_ALL=true
done

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
if [ "$OS" = "Windows_NT" ]; then
	# use blocking stdio for the remote shell (openssl) to avoid random failures (msys2/cygwin bug?)
	options="$options --blocking-io"
else
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
	elif [ -f ../../../data/xonotic-*-maps-mapping.pk3 ]; then
		echo "Found Xonotic-mappingsupport files"
		package="Xonotic-mappingsupport"
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
source="$buildtype/$package"

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
	excludes="$excludes --exclude=*.exe"
	excludes="$excludes --exclude=/bin32"
	excludes="$excludes --exclude=*.dll"
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

bestmirror=rsync.xonotic.org
if [ -z "$(rsync --help | sed -En 's/(--write-devices)/\1/p')" ]; then
	printf "\033[1;33mNOTE: your rsync version is too old for mirror autoselect and modern compression, expect bad performance. Please update to rsync 3.2.0 or later!\033[m\n"
else
	printf "Updating mirror list ... "
	out=$($rsynccmd -t "rsync://$bestmirror/autobuild/Xonotic/misc/tools/rsync-updater/mirrors.txt" mirrors.txt 2>&1) \
		&& printf "\033[0;32mOK\033[m\n" \
		|| printf "\033[1;31mFAILED\n\033[0;31m$out\033[m\n" | sed '2,${s/^/  /}'

	bestspeed=-1
	while read firstword secondword restoflineignored; do
		mirror=${firstword%%//*}
		[ -z $mirror ] && continue
		location=${secondword%%//*}
		# Sometimes perf differs greatly between v6 and v4
		for ipv in ipv6 ipv4; do
			printf "Testing mirror \033[36m$mirror\033[m [$location] $ipv ... \033[m"
			# not the most rigorous benchmark, but fit for purpose and unaffected by local filesystem perf
			# NB: /dev/null as the DEST arg is intended
			if out=$(LC_ALL=C.UTF-8 $rsynccmd --compress-choice=none --write-devices --stats --$ipv "rsync://$mirror/$source/GPL-3" /dev/null 2>&1); then
				# parse the speed from the --stats output (integer part only), and strip any commas (thousands separators)
				speed=$(printf "$out" | sed -En 's/.*  ([0-9,]+)\.?[0-9]* bytes\/sec$/\1/p' | sed 's/,//g')
				if [ -n "$speed" ]; then
					printf "\033[0;32mOK, speed $speed\033[m\n"
				else
					printf "\033[1;33mfailed to parse speed value!\n\033[0;33m$out\033[m\n" | sed '2,${s/^/  /}'
					speed=0
				fi
				if [ $speed -gt $bestspeed ]; then
					bestspeed=$speed
					bestmirror=$mirror
					bestipv=$ipv
				fi
			elif [ $ipv = ipv6 ]; then
				# omit error text to reduce spam as the ISP may not support v6
				printf "\033[0;31mFAILED\033[m\n"
			else
				printf "\033[0;31mFAILED\n\033[0;31m$out\033[m\n" | sed '2,${s/^/  /}'
			fi
		done
	done < mirrors.txt
	if [ $bestspeed -eq -1 ]; then
		printf "\033[1;31mFATAL: all mirror tests failed, no internet?\033[m\n"
		exit 1
	fi
	options="$options --$bestipv"
fi

resolvedtarget=$(cd $target && [ "${PWD#$HOME}" != "$PWD" ] && printf "~${PWD#$HOME}" || printf "$PWD")
printf "Updating \033[1;34m$resolvedtarget\033[m from \033[0;36m$bestmirror/$source \033[m$bestipv ...\n"

targetname=$(cd "$target" && printf "${PWD##*/}")
if [ $interactive != true ] && [ "$choice" != y ]; then
	printf >&2 "\033[1;31mFATAL: non-interactive mode requires the \033[1;37m--yes\033[1;31m argument to acknowledge that this will DELETE any custom files in the \"$targetname\" directory.\033[m\n"
	exit 1
fi
until [ "$choice" = y ] || [ "$choice" = Y ]; do
	printf "\033[1mThis will DELETE any custom files in the \"$targetname\" folder, continue? [Y/N] \033[m"
	read -r choice
	[ "$choice" = n ] || [ "$choice" = N ] && exit 1
done

# exec ensures this script stops before it's updated to prevent potential glitches
exec $rsynccmd $options $excludes "rsync://$bestmirror/$source/" "$target"
