#!/bin/sh

if ! [ -d "textures" ] && ! [ -d "env" ]; then
	echo "Sorry, must be run from a directory with a textures subfolder. Giving up."
	exit 1
fi

case "$0" in
	*/*)
		mydir=${0%/*}
		;;
	*)
		mydir=.
		;;
esac

makeshader()
{
	s=`texnormalize "$1"`
	dir=${s#textures/}
	dir=${dir%%/*}
	echo scripts/$dir.shader
	mkdir -p scripts
	cat <<EOF >>"scripts/$dir.shader"
$s
{
	qer_editorimage $1
	qer_trans 0.5
	// maybe: surfaceparm nonsolid
	surfaceparm trans
	surfaceparm alphashadow
	surfaceparm nomarks
	cull disable
	{
		map $s
		blendfunc blend
		// or: alphafunc GE128
	}
	{
		map \$lightmap
		blendfunc filter
		rgbGen identity
	}
}
EOF
}

makeskyshader()
{
	coords=`sh "$mydir/brightspot.sh" "$1"`
	s=`texnormalize "$1"`
	case "$coords" in
		*\ *)
			;;
		*)
			coords="-42 -42"
			echo >&2 "NOTE: brightspot tool did not work"
			;;
	esac
	s=${s%_up}
	s=${s#env/}
	dir=${s%%/*}
	echo >&2 "appending to scripts/$dir.shader"
	echo scripts/$dir.shader
	mkdir -p scripts
	cat <<EOF >>"scripts/$dir.shader"
textures/$s
{
	qer_editorimage $1
	surfaceparm noimpact
	surfaceparm nolightmap
	surfaceparm sky
	surfaceparm nomarks
	q3map_sunExt .5 .5 .7 $coords 2 16 // red green blue intensity degrees elevation deviance samples
	q3map_surfacelight 150 // intensity
	skyparms env/$s - -
}
EOF
}

texnormalize()
{
	echo "$1" | sed 's/\.[Jj][Pp][Gg]$\|\.[Tt][Gg][Aa]$\|\.[Pp][Nn][Gg]$//;'
}

allshadernames() # prints all shader names or texture names
{
	cat scripts/*.shader 2>/dev/null | tr '\r' '\n' | {
		mode=root
		while IFS= read -r LINE; do
			LINE=`echo "$LINE" | sed 's,//.*,,; s/\s\+/ /g; s/^ //; s/ $//; s/"//g;'`
			[ -n "$LINE" ] || continue
			set -- $LINE
			case "$mode:$1" in
				root:'{')
					mode=shader
					;;
				root:*)
					texnormalize "$1"
					;;

				shader:'{')
					mode=stage
					;;
				shader:'}')
					mode=root
					;;
				shader:skyparms)
					echo "`texnormalize "$1"`_up"
					;;

				stage:'}')
					mode=shader
					;;
				stage:map)
					texnormalize "$2"
					;;
				stage:clampmap)
					texnormalize "$2"
					;;
				stage:animmap)
					shift
					shift
					for X in "$@"; do
						texnormalize "$X"
					done
					;;
			esac
		done
	}
}

allshaders=`allshadernames`
lf="
"

has_shader()
{
	sh=`texnormalize "$1"`
	case "$lf$allshaders$lf" in
		*"$lf$sh$lf"*)
			return 0
			;;
	esac
	return 1
}

has_alpha()
{
	[ -f "${1%.jpg}_alpha.jpg" ] || convert "$1" -depth 8 RGBA:- | xxd -c 4 -g 1 | grep -v " ff  " >/dev/null
}

autoshaders()
{
	{
		[ -d "textures" ] && find textures -type f \( -iname \*.tga -o -iname \*.png \) -print | while IFS= read -r TEX; do
			case `texnormalize "$TEX"` in
				*_norm|*_shirt|*_pants|*_glow|*_gloss|*_bump)
					# ignore these (they are used implicitly)
					continue
					;;
			esac
			if has_shader "$TEX"; then
				echo>&2 "    $TEX has an associated shader, ignoring."
			else
				if has_alpha "$TEX"; then
					echo>&2 "*** $TEX has alpha but no shader, creating default alpha shader."
					makeshader "$TEX"
				else
					echo>&2 "    $TEX has no shader and no alpha, fine."
				fi
			fi
		done
		[ -d "env" ] && find env -type f \( -iname \*_up.tga -o -iname \*_up.png -o -iname \*_up.jpg \) -print | while IFS= read -r TEX; do
			if has_shader "$TEX"; then
				echo>&2 "    $TEX has an associated shader, ignoring."
			else
				echo>&2 "*** $TEX is sky but has no shader, creating default sky shader."
				makeskyshader "$TEX"
			fi
		done
	} | sort -u
}

aashaders=`autoshaders`

if [ -n "$aashaders" ]; then
	cat <<EOF
The following shader files have been automatically created or appended to:

$aashaders

Please edit them to your needs, and possibly rename them.
EOF
fi
