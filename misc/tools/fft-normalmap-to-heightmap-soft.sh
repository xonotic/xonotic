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
# assume we had an input range of 0 .. 1
# then this tool will scale by 2, stretching it to 1..255
# so, scale 2 means a 254/255 scale from DP's view!
extrascale=`echo "$sca / ($realscale * (127.0 / 255.0))" | bc -l`

# we want to make $realmedian + $ofs neutral
# note: ofs is in pre-scale units
extraoffset=`echo "($realmedian + $ofs / $realscale)" | bc -l`

# note: this tool maps  -1 to 1 neutral, and +1 to 255 neutral
#       darkplaces maps  1 to 0 neutral, and  0 to 255 neutral
#
# p_t(-1) = 1
# p_t(+1) = 255
#   -> p_t(x) = 128 + 127 * x
# p_d(1) = 0
# p_d(0) = 255
#   -> p_d(x) = 255 * (1 - x)
#   -> p_d^-1(x) = 1 - x / 255
#
# we need p_d^-1(p_t(x)) = 1 - (128 + 127 * x) / 255
#
extraoffset="match8 "`echo "128 + 127 * $extraoffset" | bc -l`

echo "	dpoffsetmapping - $extrascale $extraoffset"
