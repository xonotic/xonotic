#!/bin/sh

if [ -z "$1" ]; then
	echo>&2 "Usage: $0 foo_rt.jpg"
	exit 1
fi

brightspot=
if which brightspot-bin >/dev/null; then
	brightspot=brightspot-bin
else
	case "$0" in
		*/*)
			mydir=${0%/*}
			;;
		*)
			mydir=.
			;;
	esac
	brightspot="$mydir/brightspot-bin"
	[ "$brightspot" -nt "$mydir/brightspot.c" ] || gcc -lm -O3 -Wall -Wextra "$mydir/brightspot.c" -o "$brightspot" || exit 1
fi

i=$1
ext=${i##*.}
name=${i%.*}
name=${name%_[rlbfud][tfktpn]}

{
	convert "$name"_rt."$ext" -depth 8 -geometry 512x512 GRAY:-
	convert "$name"_lf."$ext" -depth 8 -geometry 512x512 GRAY:-
	convert "$name"_bk."$ext" -depth 8 -geometry 512x512 GRAY:-
	convert "$name"_ft."$ext" -depth 8 -geometry 512x512 GRAY:-
	convert "$name"_up."$ext" -depth 8 -geometry 512x512 GRAY:-
	convert "$name"_dn."$ext" -depth 8 -geometry 512x512 GRAY:-
} | "$brightspot" /dev/stdin
