#!/bin/sh

set -e

: ${CACHEDIR:=$HOME/.xonotic-cached-converter}
: ${do_jpeg:=true}
: ${do_jpeg_if_not_dds:=false}
: ${jpeg_qual_rgb:=95}
: ${jpeg_qual_a:=99}
: ${do_dds:=true}
: ${dds_tool:=compressonator-dxtc}
: ${do_ogg:=false}
: ${ogg_qual:=1}
: ${del_src:=false}

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

lastinfiles=
lastinfileshash=
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
	if [ x"$infile1" = x"$outfile1" ]; then
		keep=true
	fi
	options=`echo "$*" | git hash-object --stdin`
	if [ x"$infile1/../$infile2" = x"$lastinfiles" ]; then
		sum=$lastinfileshash
	else
		sum=`git hash-object "$infile1"`
		if [ -n "$infile2" ]; then
			sum=$sum`git hash-object "$infile2"`
		fi
		lastinfileshash=$sum
	fi
	mkdir -p "$CACHEDIR/$method-$options"
	name1="$CACHEDIR/$method-$options/$sum-1.${outfile1##*.}"
	[ -z "$outfile2" ] || name2="$CACHEDIR/$method-$options/$sum-2.${outfile2##*.}"
	tempfile1="${name1%/*}/new-${name1##*/}"
	[ -z "$outfile2" ] || tempfile2="${name2%/*}/new-${name2##*/}"
	if [ -f "$name1" ] && { [ -z "$outfile2" ] || [ -f "$name2" ]; }; then
		case "$outfile1" in */*) mkdir -p "${outfile1%/*}"; esac && { ln "$name1" "$outfile1" 2>/dev/null || cp "$name1" "$outfile1"; }
		[ -z "$outfile2" ] || { case "$outfile2" in */*) mkdir -p "${outfile2%/*}"; esac && { ln "$name2" "$outfile2" 2>/dev/null || cp "$name2" "$outfile2"; }; }
		conv=true
	elif "$method" "$infile1" "$infile2" "$tempfile1" "$tempfile2" "$@"; then
		mv "$tempfile1" "$name1"
		[ -z "$outfile2" ] || mv "$tempfile2" "$name2"
		case "$outfile1" in */*) mkdir -p "${outfile1%/*}"; esac && { ln "$name1" "$outfile1" 2>/dev/null || cp "$name1" "$outfile1"; }
		[ -z "$outfile2" ] || { case "$outfile2" in */*) mkdir -p "${outfile2%/*}"; esac && { ln "$name2" "$outfile2" 2>/dev/null || cp "$name2" "$outfile2"; }; }
		conv=true
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

reduce_ogg_ogg()
{
	i=$1; shift; shift
	o=$1; shift; shift
	tags=`vorbiscomment -R -l "$i"`
	oggdec -o "$tmpdir/x.wav" "$i" && \
	oggenc -q"$1" -o "$o" "$tmpdir/x.wav"
	echo "$tags" | vorbiscomment -R -w "$o"
}

reduce_wav_ogg()
{
	i=$1; shift; shift
	o=$1; shift; shift
	oggenc -q"$1" -o "$o" "$i"
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
	convert "$i" -alpha off     -quality 100 "$o" && \
	convert "$i" -alpha extract -quality 100 "$oa" && \
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

has_alpha()
{
	i=$1; shift; shift
	o=$1; shift; shift
	if convert "$F" -depth 16 RGBA:- | perl -e 'while(read STDIN, $_, 8) { substr($_, 6, 2) eq "\xFF\xFF" or exit 1; } exit 0;'; then
		# no alpha
		: > "$o"
	else
		# has alpha
		echo yes > "$o"
	fi
}

to_delete=
for F in "$@"; do
	f=${F%.*}

	echo >&2 "Handling $F..."
	conv=false
	keep=false

	will_jpeg=$do_jpeg
	will_dds=$do_dds
	case "$f" in
		./models/player/*) will_dds=false ;;
		./textures/*) ;;
		./models/*) ;;
		./particles/*) ;;
		./progs/*) ;;
		*)
			# we can't DDS compress the 2D textures, sorry
			# but JPEG is still fine
			will_dds=false
			;;
	esac

	if $do_jpeg_if_not_dds; then
		if $will_dds; then
			will_jpeg=false
		else
			will_jpeg=true
		fi
	fi

	case "$F" in
		*_alpha.jpg)
			# handle in *.jpg case

			# they always got converted, I assume
			if $will_dds || $will_jpeg; then
				conv=true
			fi
			keep=$will_jpeg
			;;
		*.jpg)
			if [ -f "${f}_alpha.jpg" ]; then
				cached "$will_dds"  reduce_jpeg2_dds   "$F" "${f}_alpha.jpg" "dds/${f}.dds" ""               "$dds_flags"
				cached "$will_jpeg" reduce_jpeg2_jpeg2 "$F" "${f}_alpha.jpg" "$F"           "${f}_alpha.jpg" "$jpeg_qual_rgb" "$jpeg_qual_a"
			else                                   
				cached "$will_dds"  reduce_rgb_dds     "$F" ""               "dds/${f}.dds" ""               "$dds_flags"
				cached "$will_jpeg" reduce_jpeg_jpeg   "$F" ""               "$F"           ""               "$jpeg_qual_rgb"
			fi
			;;
		*.png|*.tga)
			cached true has_alpha "$F" "" "$F.hasalpha" ""
			conv=false
			if [ -s "$F.hasalpha" ]; then
				cached "$will_dds"  reduce_rgba_dds    "$F" ""               "dds/${f}.dds" ""               "$dds_flags"
				cached "$will_jpeg" reduce_rgba_jpeg2  "$F" ""               "${f}.jpg"     "${f}_alpha.jpg" "$jpeg_qual_rgb" "$jpeg_qual_a"
			else                                                             
				cached "$will_dds"  reduce_rgb_dds     "$F" ""               "dds/${f}.dds" ""               "$dds_flags"
				cached "$will_jpeg" reduce_rgb_jpeg    "$F" ""               "${f}.jpg"     ""               "$jpeg_qual_rgb"
			fi
			rm -f "$F.hasalpha"
			;;
		*.ogg)
			cached "$do_ogg" reduce_ogg_ogg "$F" "" "$F" "" "$ogg_qual"
			;;
		*.wav)
			cached "$do_ogg" reduce_wav_ogg "$F" "" "$F" "" "$ogg_qual"
			;;
	esac
	if $del_src; then
		if $conv; then
			if ! $keep; then
				# FIXME can't have spaces in filenames that way
				to_delete="$to_delete $F"
			fi
		fi
	fi
	# fix up DDS paths by a symbolic link
	if [ -f "dds/${f}.dds" ]; then
		if [ -z "${f##./textures/*}" ]; then
			if [ -n "${f##./textures/*/*}" ]; then
				ln -snf "textures/${f#./textures/}.dds" "dds/${f#./textures/}.dds"
			fi
		fi
	fi
done
for F in $to_delete; do
	rm -f "$F"
done
