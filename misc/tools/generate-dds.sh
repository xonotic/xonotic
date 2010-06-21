#!/bin/sh

set -e

for X in "$@"; do
	case "$X" in
		*.jpg)
			if [ -n "$scaledown" ]; then
				mogrify -geometry "$scaledown" -quality 100 "$X"
			fi
			echo "$X has no alpha, converting"
			nvcompress -bc1 "$X" "${X%.*}.dds"
			rm -f "$X"
			;;
		*.png|*.tga)
			if [ -n "$scaledown" ]; then
				mogrify -geometry "$scaledown" -quality 100 "$X"
			fi
			if convert "$X" -depth 16 RGBA:- | perl -e 'while(read STDIN, $_, 8) { substr($_, 6, 2) eq "\xFF\xFF" or exit 1; ++$pix; } exit not $pix;'; then
				echo "$X has no alpha, converting"
				nvcompress -bc1 "$X" "${X%.*}.dds"
				rm -f "$X"
			else
				echo "$X has alpha, converting"
				nvcompress -alpha -bc3 "$X" "${X%.*}.dds"
				rm -f "$X"
			fi
			;;
	esac
done
