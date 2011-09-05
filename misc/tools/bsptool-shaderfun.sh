#!/bin/sh

# input: a .shader file
# parameters: in and out .bsp file

BSPTOOL="${0%/*}"/bsptool.pl
LF="
"

in=$1
out=$2

shaders=`"$BSPTOOL" "$in" -S`

newshaders=`cat | grep '^[^ 	{}]'`

set --

list=
for shader in $shaders; do
	if [ -z "$list" ]; then
		echo >&2 "Filling list..."
		list=`echo "$newshaders" | sort -R`$LF
	fi
	case "$shader" in
		noshader|NULL|textures/common/*)
			;;
		*)
			item=${list%%$LF*}
			list=${list#*$LF}
			set -- "$@" "-S$shader=$item"
			;;
	esac
done

set -- "$BSPTOOL" "$in" "$@" -o"$out"
"$@"
