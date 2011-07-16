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
: ${git_src_repo:=}
: ${dds_noalpha:=dxt1}
: ${dds_prealpha:=dxt2 dxt4}
: ${dds_sepalpha:=dxt3 dxt5}

selfprofile_t0=`date +%s`
selfprofile_step=init
selfprofile()
{
	selfprofile_t=`date +%s`
	eval "selfprofile_counter_$selfprofile_step=\$((\$selfprofile_counter_$selfprofile_step+$selfprofile_t))"
	selfprofile_step=$1
	eval "selfprofile_counter_$selfprofile_step=\$((\$selfprofile_counter_$selfprofile_step-$selfprofile_t))"
	selfprofile_t0=$selfprofile_t
}

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


use_magnet_to_acquire_checksum_faster()
#             ___________________
#        ,--'' ~~~~~~~^^^~._     '.
#    ,.-' ~~~~~~~~~~^^^^^~~~._._   \
#    |   /^^^^^|    /^^^^^^^^\\ \   \
#  ,/___  <  o>      <  (OO) > _     \
# /'/,         |-         .       ----.\
# |(|-'^^;,-  ,|     __    ^~~^^^^^^^; |\
# \\`  |    <;_    __ |`---  ..-^^/- | ||
#  \`-|Oq-.____`________~='^^|__,/  ' //
#   \ || | |   |  |    \ ..-;|  /    '/
#   | ||#|#|the|==|game!|'^` |/'    /'
#   | \\\\^\***|***|    \ ,,;'     /
#   |  `-=\_\__\___\__..-' ,.- - ,/
#   | . `-_  ------   _,-'^-'^,-'
#   | `-._________..--''^,-''^
#   \             ,...-'^
#    `----------'^              PROBLEM?
{
	magnet=`GIT_DIR="$git_src_repo/.git" git ls-files -s "$1"`
	if [ -n "$magnet" ]; then
		magnet=${magnet#* }
		magnet=${magnet%% *}
		sum=$sum$magnet
	else
		sum=$sum`git hash-object "$1"`
	fi
}

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
	#sleep 0.25
	if [ x"$infile1" = x"$outfile1" ]; then
		keep=true
	fi
	options=`echo "$*" | git hash-object --stdin`
	selfprofile convert_findchecksum
	if [ x"$infile1/../$infile2" = x"$lastinfiles" ]; then
		sum=$lastinfileshash
	else
		evil=false
		for infile in "$infile1" "$infile2"; do
			case "$infile" in
				*/background_l2.tga|*/background_ingame_l2.tga)
					evil=true
					;;
			esac
		done
		if [ -n "$git_src_repo" ] && ! $evil; then
			sum=
			use_magnet_to_acquire_checksum_faster "${infile1#./}"
			if [ -n "$infile2" ]; then
				use_magnet_to_acquire_checksum_faster "${infile2#./}"
			fi
		else
			sum=`git hash-object "$infile1"`
			if [ -n "$infile2" ]; then
				sum=$sum`git hash-object "$infile2"`
			fi
		fi
		lastinfileshash=$sum
	fi
	selfprofile convert_makecachedir
	mkdir -p "$CACHEDIR/$method-$options"
	name1="$CACHEDIR/$method-$options/$sum-1.${outfile1##*.}"
	[ -z "$outfile2" ] || name2="$CACHEDIR/$method-$options/$sum-2.${outfile2##*.}"
	tempfile1="${name1%/*}/new-${name1##*/}"
	[ -z "$outfile2" ] || tempfile2="${name2%/*}/new-${name2##*/}"
	if [ -f "$name1" ] && { [ -z "$outfile2" ] || [ -f "$name2" ]; }; then
		selfprofile convert_copyoutput
		case "$outfile1" in */*) mkdir -p "${outfile1%/*}"; esac && { ln -f "$name1" "$outfile1" 2>/dev/null || { rm -f "$outfile1" && cp "$name1" "$outfile1"; }; }
		[ -z "$outfile2" ] || { case "$outfile2" in */*) mkdir -p "${outfile2%/*}"; esac && { ln -f "$name2" "$outfile2" 2>/dev/null || { rm -f "$outfile2" && cp "$name2" "$outfile2"; }; }; }
		conv=true
	elif selfprofile convert_makeoutput; "$method" "$infile1" "$infile2" "$tempfile1" "$tempfile2" "$@"; then
		mv "$tempfile1" "$name1"
		[ -z "$outfile2" ] || mv "$tempfile2" "$name2"
		case "$outfile1" in */*) mkdir -p "${outfile1%/*}"; esac && { ln -f "$name1" "$outfile1" 2>/dev/null || { rm -f "$outfile1" && cp "$name1" "$outfile1"; }; }
		[ -z "$outfile2" ] || { case "$outfile2" in */*) mkdir -p "${outfile2%/*}"; esac && { ln -f "$name2" "$outfile2" 2>/dev/null || { rm -f "$outfile2" && cp "$name2" "$outfile2"; }; }; }
		conv=true
	else
		selfprofile convert_cleartemp
		rm -f "$tempfile1"
		rm -f "$tempfile2"
		selfprofile convert_finished
		exit 1
	fi
	selfprofile convert_finished
}

pickdxta()
{
	pd_t=$1; shift
	pd_d=$1; shift
	pd_i=$1; shift
	pd_o=$1; shift
	for pd_dd in $pd_d; do
		if [ -f "$pd_o" ]; then
			"$meprefix"compress-texture "$pd_t" "$pd_dd" "$pd_i" "$pd_o".tmp.dds "$@"
			pd_psnr_tmp=`compare -channel alpha -metric PSNR "$pd_i" "$pd_o".tmp.dds NULL: 2>&1`
			case "$pd_psnr_tmp" in
				[0-9.]*)
					;;
				*)
					pd_psnr_tmp=999.9
					;;
			esac
			echo >&2 "$pd_dd: $pd_psnr_tmp dB"
			pd_psnr_diff=`echo "($pd_psnr_tmp) - ($pd_psnr)" | bc -l`
			case "$pd_psnr_diff" in
				-*|0)
					# tmp is smaller or equal
					# smaller PSNR is worse
					# no action
					;;
				*)
					# tmp is larger
					# larger PSNR is better
					pd_psnr=$pd_psnr_tmp
					mv "$pd_o".tmp.dds "$pd_o"
					echo >&2 "PICKED (better)"
					;;
			esac
		else
			"$meprefix"compress-texture "$pd_t" "$pd_dd" "$pd_i" "$pd_o" "$@"
			pd_psnr=`compare -channel alpha -metric PSNR "$pd_i" "$pd_o" NULL: 2>&1`
			case "$pd_psnr" in
				[0-9.]*)
					;;
				*)
					pd_psnr=999.9
					;;
			esac
			echo >&2 "$pd_dd: $pd_psnr dB"
			echo >&2 "PICKED (first)"
		fi
	done
}

reduce_jpeg2_dds()
{
	i=$1; shift
	ia=$1; shift
	o=$1; shift; shift 
	convert "$i" "$ia" -compose CopyOpacity -composite "$tmpdir/x.tga" && \
	pickdxta "$dds_tool" "$dds_sepalpha" "$tmpdir/x.tga" "$o" $1
}

reduce_jpeg2_dds_premul()
{
	i=$1; shift
	ia=$1; shift
	o=$1; shift; shift 
	convert "$i" "$ia" -compose CopyOpacity -composite "$tmpdir/x.tga" && \
	pickdxta "$dds_tool" "$dds_prealpha" "$tmpdir/x.tga" "$o" $1
}

reduce_jpeg2_jpeg2()
{
	i=$1; shift
	ia=$1; shift
	o=$1; shift
	oa=$1; shift
	if convert "$i" TGA:- | cjpeg -targa -quality "$1" -optimize -sample 1x1,1x1,1x1 > "$o"; then
		if [ "`stat -c %s "$i"`" -lt "`stat -c %s "$o"`" ]; then
			cp "$i" "$o"
		fi
	else
		return 1
	fi
	if convert "$ia" TGA:- | cjpeg -targa -quality "$2" -optimize -sample 1x1,1x1,1x1 > "$oa"; then
		if [ "`stat -c %s "$ia"`" -lt "`stat -c %s "$oa"`" ]; then
			cp "$ia" "$oa"
		fi
	else
		return 1
	fi
}

reduce_jpeg_jpeg()
{
	i=$1; shift; shift
	o=$1; shift; shift
	if convert "$i" TGA:- | cjpeg -targa -quality "$1" -optimize -sample 1x1,1x1,1x1 > "$o"; then
		if [ "`stat -c %s "$i"`" -lt "`stat -c %s "$o"`" ]; then
			cp "$i" "$o"
		fi
	else
		return 1
	fi
}

reduce_ogg_ogg()
{
	i=$1; shift; shift
	o=$1; shift; shift
	tags=`vorbiscomment -R -l "$i" || true`
	oggdec -o "$tmpdir/x.wav" "$i" && \
	oggenc -q"$1" -o "$o" "$tmpdir/x.wav"
	echo "$tags" | vorbiscomment -R -w "$o" || true
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
	pickdxta "$dds_tool" "$dds_sepalpha" "$tmpdir/x.tga" "$o" $1
}

reduce_rgba_dds_premul()
{
	i=$1; shift; shift
	o=$1; shift; shift
	convert "$i" "$tmpdir/x.tga" && \
	pickdxta "$dds_tool" "$dds_prealpha" "$tmpdir/x.tga" "$o" $1
}

reduce_rgba_jpeg2()
{
	i=$1; shift; shift
	o=$1; shift
	oa=$1; shift
	if convert "$i" -alpha off TGA:- | cjpeg -targa -quality "$1" -optimize -sample 1x1,1x1,1x1 > "$o"; then
		:
	else
		return 1
	fi
	if convert "$i" -alpha extract TGA:- | cjpeg -targa -quality "$2" -optimize -sample 1x1,1x1,1x1 > "$oa"; then
		:
	else
		return 1
	fi
}

reduce_rgb_dds()
{
	i=$1; shift; shift
	o=$1; shift; shift
	convert "$i" "$tmpdir/x.tga" && \
	"$meprefix"compress-texture "$dds_tool" "$dds_noalpha" "$tmpdir/x.tga" "$o" $1
}

reduce_rgb_jpeg()
{
	i=$1; shift; shift
	o=$1; shift; shift
	if convert "$i" TGA:- | cjpeg -targa -quality "$1" -optimize -sample 1x1,1x1,1x1 > "$o"; then
		:
	else
		return 1
	fi
}

has_alpha()
{
	i=$1; shift; shift
	o=$1; shift; shift
	if convert "$i" -depth 16 RGBA:- | perl -e 'while(read STDIN, $_, 8) { substr($_, 6, 2) eq "\xFF\xFF" or exit 1; } exit 0;'; then
		# no alpha
		: > "$o"
	else
		# has alpha
		echo yes > "$o"
	fi
}

to_delete=
for F in "$@"; do
	selfprofile prepareconvert
	f=${F%.*}

	echo >&2 "Handling $F..."
	conv=false
	keep=false
	jqual_rgb=$jpeg_qual_rgb
	jqual_a=$jpeg_qual_a

	will_jpeg=$do_jpeg
	will_dds=$do_dds
	will_ogg=$do_ogg
	case "$f" in
		./sounds/misc/talk*.wav) will_ogg=false ;; # engine "feature"
		*_bump) will_dds=false ;;
		./models/player/*) will_dds=false ;;
		./models/sprites/*) will_dds=false ;;
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

	# configure S2TC
	case "$f" in
		*_norm)
			export S2TC_COLORDIST_MODE=NORMALMAP
			export S2TC_RANDOM_COLORS=256
			export S2TC_REFINE_COLORS=LOOP
			;;
		*)
			export S2TC_COLORDIST_MODE=SRGB_MIXED
			export S2TC_RANDOM_COLORS=64
			export S2TC_REFINE_COLORS=LOOP
			;;
	esac

	# for deluxemaps, lightmaps and normalmaps, enforce high jpeg quality (like on alpha channels)
	if [ "$jqual_a" -gt "$jqual_rgb" ]; then
		case "$f" in
			./maps/*/lm_[0-9][0-9][0-9][13579]) # deluxemap
				jqual_rgb=$jqual_a
				;;
			./maps/*/lm_[0-9][0-9][0-9][02468]) # lightmap
				jqual_rgb=$jqual_a
				;;
			*_norm) # normalmap
				jqual_rgb=$jqual_a
				;;
		esac
	fi

	pm=
	case "$f" in
		./particles/particlefont) # particlefont uses premultiplied alpha
			pm=_premul
			;;
	esac

	if $do_jpeg_if_not_dds; then
		if $will_dds; then
			will_jpeg=false
		else
			will_jpeg=true
		fi
	fi
	selfprofile startconvert
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
				cached "$will_dds"  reduce_jpeg2_dds$pm "$F" "${f}_alpha.jpg" "dds/${f}.dds" ""               "$dds_flags"
				cached "$will_jpeg" reduce_jpeg2_jpeg2  "$F" "${f}_alpha.jpg" "$F"           "${f}_alpha.jpg" "$jqual_rgb" "$jqual_a"
			else                                   
				cached "$will_dds"  reduce_rgb_dds      "$F" ""               "dds/${f}.dds" ""               "$dds_flags"
				cached "$will_jpeg" reduce_jpeg_jpeg    "$F" ""               "$F"           ""               "$jqual_rgb"
			fi
			;;
		*.png|*.tga)
			cached true has_alpha "$F" "" "$F.hasalpha" ""
			conv=false
			if [ -s "$F.hasalpha" ]; then
				cached "$will_dds"  reduce_rgba_dds$pm  "$F" ""               "dds/${f}.dds" ""               "$dds_flags"
				cached "$will_jpeg" reduce_rgba_jpeg2   "$F" ""               "${f}.jpg"     "${f}_alpha.jpg" "$jqual_rgb" "$jqual_a"
			else                                                             
				cached "$will_dds"  reduce_rgb_dds      "$F" ""               "dds/${f}.dds" ""               "$dds_flags"
				cached "$will_jpeg" reduce_rgb_jpeg     "$F" ""               "${f}.jpg"     ""               "$jqual_rgb"
			fi
			rm -f "$F.hasalpha"
			;;
		*.ogg)
			cached "$will_ogg" reduce_ogg_ogg "$F" "" "$F" "" "$ogg_qual"
			;;
		./sound/misc/null.wav)
			# never convert this one
			;;
		*.wav)
			cached "$will_ogg" reduce_wav_ogg "$F" "" "${f}.ogg" "" "$ogg_qual"
			;;
	esac
	selfprofile marktodelete
	if $del_src; then
		if $conv; then
			if ! $keep; then
				# FIXME can't have spaces in filenames that way
				to_delete="$to_delete $F"
			fi
		fi
	fi
	selfprofile symlinkfixing
	# fix up DDS paths by a symbolic link
	if [ -f "dds/${f}.dds" ]; then
		if [ -z "${f##./textures/*}" ]; then
			if [ -n "${f##./textures/*/*}" ]; then
				ln -snf "textures/${f#./textures/}.dds" "dds/${f#./textures/}.dds"
			fi
		fi
	fi
	selfprofile looping
done

for F in $to_delete; do
	rm -f "$F"
done
selfprofile finished_time
set | grep ^selfprofile_counter_ >&2
