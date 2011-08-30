#!/bin/sh

i=$1
o=$2
f=$3
sca=$4
ofs=$5

s=`"${0%-soft.sh}" "$i" "$o" "$f"`
echo >&2 "$s"

# we want to map so that:
#   sca
#   med/avg -> ofs

realscale=`echo "$s" | grep ^Scale: | cut -d ' ' -f 2`
realmedian=`echo "$s" | grep ^Scaled-Med: | cut -d ' ' -f 2`

# we have to undo realscale, and apply sca instead
extrascale=`echo "$sca / $realscale" | bc -l`

# we want to make $realmedian + $ofs neutral

extraoffset=`echo "127.5 - 127.5 * ($realmedian + $ofs)" | bc -l`

echo "dpoffsetmapping - $extrascale $extraoffset"
