#!/bin/sh

case "$2" in
	old)
		PATTERN='all-time fastest lap record with (.*)\n'
		;;
	new|*)
		PATTERN='//RA?CE? RECORD SET (.*)\n'
		;;
esac

d=$1
i=0
demotc.pl grep "$d" "$PATTERN" | while IFS=" " read -r timecode result; do
	timecode=${timecode%:}
	result=${result#\"}
	result=${result%\"}
	result=${result%% *}

	echo "Possible record found at $timecode: $result, extracting..."

	minutes=${result%%:*}
	result=${result#*:}
	seconds=${result%%.*}
	result=${result#*.}
	tenths=$result

	timecode_start=`echo "$timecode - $minutes*60 - $seconds - $tenths*0.1 - 2" | bc -l`
	timecode_end=`echo "$timecode + 2" | bc -l`
	i=$(($i + 1))
	demotc.pl cut "$d" "playback-$i.dem" "$timecode_start" "$timecode_end"
	demotc.pl cut "$d" "capture-$i.dem" "$timecode_start" "$timecode_end" --capture
done
