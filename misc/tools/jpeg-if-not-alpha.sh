#!/bin/sh

set -e

: ${qual:=95}

for X in "$@"; do
	case "$X" in
		*.jpg)
			if [ -n "$scaledown" ]; then
				mogrify -geometry "$scaledown>" -quality 100 "$X"
			fi
			jpegoptim --strip-all -m$qual "$X"
			;;
		*.png|*.tga)
			if [ -n "$scaledown" ]; then
				mogrify -geometry "$scaledown>" -quality 100 "$X"
			fi
			if convert "$X" -depth 16 RGBA:- | perl -e 'while(read STDIN, $_, 8) { substr($_, 6, 2) eq "\xFF\xFF" or exit 1; ++$pix; } exit not $pix;'; then
				echo "$X has no alpha, converting"
				convert "$X" -quality 100 "${X%.*}.jpg"
				jpegoptim --strip-all -m$qual "${X%.*}.jpg"
				rm -f "$X"
			else
				echo "$X has alpha, not converting"
			fi
			;;
	esac
done
