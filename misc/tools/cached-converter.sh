#!/bin/sh

set -e

: ${CACHEDIR:=$HOME/.xonotic-cached-converter}
: ${do_jpeg:=true}
: ${jpeg_qual_rgb:=95}
: ${jpeg_qual_a:=99}
: ${do_dds:=true}
: ${dds_tool:=compressonator-dxtc}
: ${do_ogg:=false}
: ${ogg_qual:=1}

me=$0
case "$me" in
	*/*)
		meprefix=${me%/*}/
		;;
	*)
		meprefix=
		;;
esac

tmpdir=`mktemp -d -t cached-converter.XXXXXX`
trap 'exit 1' INT
trap 'rm -rf "$tmpdir"' EXIT

cached()
{
	flag=$1; shift
	method=$1; shift
	infile1=$1; shift
	infile2=$1; shift
	outfile1=$1; shift
	outfile2=$1; shift
	if ! $flag; then
		return 0
	fi
	options=`echo "$*" | git hash-object --stdin`
	sum=`git hash-object "$infile1"`
	if [ -n "$infile2" ]; then
		sum=$sum`git hash-object "$infile2"`
	fi
	mkdir -p "$CACHEDIR/$method-$options"
	name1="$CACHEDIR/$method-$options/$sum-1.${outfile1##*.}"
	[ -z "$outfile2" ] || name2="$CACHEDIR/$method-$options/$sum-2.${outfile2##*.}"
	tempfile1="${name1%/*}/new-${name1##*/}"
	[ -z "$outfile2" ] || tempfile2="${name2%/*}/new-${name2##*/}"
	[ -z "${outfile1##*/*}" ] && mkdir -p "${outfile1%/*}"
	[ -z "$outfile2" ] || { [ -z "${outfile2##*/*}" ] && mkdir -p "${outfile2%/*}"; }
	if [ -f "$name1" ]; then
		ln "$name1" "$outfile1" 2>/dev/null || cp "$name1" "$outfile1"
		[ -z "$outfile2" ] || ln "$name2" "$outfile2" 2>/dev/null || cp "$name2" "$outfile2"
	elif "$method" "$infile1" "$infile2" "$tempfile1" "$tempfile2" "$@"; then
		mv "$tempfile1" "$name1"
		[ -z "$outfile2" ] || mv "$tempfile2" "$name2"
		case "$outfile1" in */*) mkdir -p "${outfile1%/*}"; esac && { ln "$name1" "$outfile1" 2>/dev/null || cp "$name1" "$outfile1"; }
		[ -z "$outfile2" ] || { case "$outfile2" in */*) mkdir -p "${outfile2%/*}"; esac && { ln "$name2" "$outfile2" 2>/dev/null || cp "$name2" "$outfile2"; }; }
	else
		rm -f "$tempfile1"
		rm -f "$tempfile2"
		exit 1
	fi
}

reduce_jpeg2_dds()
{
	i=$1; shift
	ia=$1; shift
	o=$1; shift; shift 
	convert "$i" "$ia" -compose CopyOpacity -composite "$tmpdir/x.tga" && \
	"$meprefix"compress-texture "$dds_tool" dxt5 "$tmpdir/x.tga" "$o" $1
}

reduce_jpeg2_jpeg2()
{
	i=$1; shift
	ia=$1; shift
	o=$1; shift
	oa=$1; shift
	cp "$i" "$o" && jpegoptim --strip-all -m"$1" "$o" && \
	cp "$ia" "$oa" && jpegoptim --strip-all -m"$2" "$oa"
}

reduce_jpeg_jpeg()
{
	i=$1; shift; shift
	o=$1; shift; shift
	cp "$i" "$o" && jpegoptim --strip-all -m"$1" "$o"
}

reduce_ogg()
{
	i=$1; shift; shift
	o=$1; shift; shift
	oggdec -o "$tmpdir/x.wav" "$i" && \
	oggenc -q"$1" -o "$o" "$tmpdir/x.wav"
}

reduce_rgba_dds()
{
	i=$1; shift; shift
	o=$1; shift; shift
	convert "$i" "$tmpdir/x.tga" && \
	"$meprefix"compress-texture "$dds_tool" dxt5 "$tmpdir/x.tga" "$o" $1
}

reduce_rgba_jpeg2()
{
	i=$1; shift; shift
	o=$1; shift
	oa=$1; shift
	convert "$i" -alpha extract -quality 100 "$o" && \
	convert "$i" -alpha off     -quality 100 "$oa" && \
	jpegoptim --strip-all -m"$1" "$o" && \
	jpegoptim --strip-all -m"$2" "$oa"
}

reduce_rgb_dds()
{
	i=$1; shift; shift
	o=$1; shift; shift
	convert "$i" "$tmpdir/x.tga" && \
	"$meprefix"compress-texture "$dds_tool" dxt1 "$tmpdir/x.tga" "$o" $1
}

reduce_rgb_jpeg()
{
	i=$1; shift; shift
	o=$1; shift; shift
	convert "$i" "$o" && \
	jpegoptim --strip-all -m"$1" "$o"
}


for F in "$@"; do
	case "$F" in
	*_alpha.jpg)
		# handle in *.jpg case
		;;
	*.jpg)
		if [ -f "${F%.jpg}_alpha.jpg" ]; then
			cached "$do_dds"  reduce_jpeg2_dds   "$F" "${F%.*}_alpha.jpg" "dds/${F%.*}.dds" ""                  "$dds_flags"
			cached "$do_jpeg" reduce_jpeg2_jpeg2 "$F" "${F%.*}_alpha.jpg" "$F"              "${F%.*}_alpha.jpg" "$jpeg_qual_rgb" "$jpeg_qual_a"
		else                                   
			cached "$do_dds"  reduce_rgb_dds     "$F" ""                  "dds/${F%.*}.dds" ""                  "$dds_flags"
			cached "$do_jpeg" reduce_jpeg_jpeg   "$F" ""                  "$F"              ""                  "$jpeg_qual_rgb"
		fi
		;;
	*.png|*.tga)
		if convert "$F" -depth 16 RGBA:- | perl -e 'while(read STDIN, $_, 8) { substr($_, 6, 2) eq "\xFF\xFF" or exit 1; } exit 0;'; then
			cached "$do_dds"  reduce_rgb_dds     "$F" ""                  "dds/${F%.*}.dds" ""                  "$dds_flags"
			cached "$do_jpeg" reduce_rgb_jpeg    "$F" ""                  "${F%.*}.jpg"     ""                  "$jpeg_qual_rgb"
			rm -f "$F"
		else                                                             
			cached "$do_dds"  reduce_rgba_dds    "$F" ""                  "dds/${F%.*}.dds" ""                  "$dds_flags"
			cached "$do_jpeg" reduce_rgba_jpeg2  "$F" ""                  "${F%.*}.jpg"     "${F%.*}_alpha.jpg" "$jpeg_qual_rgb" "$jpeg_qual_a"
			rm -f "$F"
		fi
		;;
	*.ogg)
		cached "$do_ogg" reduce_ogg "$F" "" "$F" "" "$ogg_qual"
		;;
	esac
done
