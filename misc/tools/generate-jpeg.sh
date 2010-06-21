#!/bin/sh

set -e

: ${qual:=95}
: ${qual_alpha:=99}

for X in "$@"; do
	case "$X" in
		*.jpg)
			jpegoptim --strip-all -m$qual "$X"
			;;
		*.png|*.tga)
			if convert "$X" -depth 16 RGBA:- | perl -e 'while(read STDIN, $_, 8) { substr($_, 6, 2) eq "\xFF\xFF" or exit 1; ++$pix; } exit not $pix;'; then
				echo "$X has no alpha, converting"
				convert "$X" -quality 100 "${X%.*}.jpg"
				jpegoptim --strip-all -m$qual "${X%.*}.jpg"
				rm -f "$X"
			else
				echo "$X has alpha, converting twice"
				convert "$X" -alpha extract -quality 100 "${X%.*}.jpg"
				convert "$X" -alpha off     -quality 100 "${X%.*}_alpha.jpg"
				jpegoptim --strip-all -m$qual "${X%.*}.jpg"
				jpegoptim --strip-all -m$qual_alpha "${X%.*}_alpha.jpg"
				rm -f "$X"
			fi
			;;
	esac
done
