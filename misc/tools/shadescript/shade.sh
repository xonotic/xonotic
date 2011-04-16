#!/bin/sh

case "$#" in
	2)
		;;
	*)
		echo "Usage: from xonotic-maps.pk3dir directory, copy and edit shader.template, then"
		echo "  $0 texturepackname myshader.template"
		exit 1
		;;
esac

LF="
"

exec 3>"scripts/$1.shader"
template=`cat "$2"`

find "textures/$1" -type f -path "textures/*/*/*.*" -not -name '*_norm.*' -not -name '*_glow.*' -not -name '*_gloss.*' -not -name '*_reflect.*' -not -name '*.xcf' | while IFS= read -r F; do
	F=${F%.*}

	noLightmap=false
	isLiquid=false
	isTransparent=false
	bounceScale=1.00
	shaderString="$template"
	shaderHead=
	shaderTail=
	shaderQUI=
	shaderDiffuse=
	diffuseExtra=

	case "$F" in
		*decal*)
			noLightmap=true
			;;
	esac

	# material type
	case "$F" in
		*water*)
			noLightmap=true
			isLiquid=true
			shaderHead="$shaderHead	surfaceparm trans$LF	surfaceparm water$LF	qer_trans 20$LF"
			;;
		*slime*)
			noLightmap=true
			isLiquid=true
			shaderHead="$shaderHead	surfaceparm trans$LF	surfaceparm slime$LF	qer_trans 20$LF"
			;;
		*lava*)
			noLightmap=true
			isLiquid=true
			shaderHead="$shaderHead	surfaceparm trans$LF	surfaceparm lava$LF	qer_trans 20$LF"
			;;
		*glass*)
			noLightmap=true
			shaderHead="$shaderHead	surfaceparm trans$LF"
			diffuseExtra="$diffuseExtra		blendfunc add$LF"
			;;
		*metal*)
			bounceScale=`echo "$bounceScale + 0.25" | bc -l`
			shaderHead="$shaderHead	surfaceparm metalsteps$LF"
			;;
	esac

	# what is it used for
	case "$F" in
		*grate*)
			bounceScale=`echo "$bounceScale + 0.25" | bc -l`
			shaderHead="$shaderHead	surfaceparm trans$LF"
			diffuseExtra="$diffuseExtra		blendfunc blend$LF"
			;;
	esac

	# further properties
	case "$F" in
		*shiny*)
			bounceScale=`echo "$bounceScale + 0.25" | bc -l`
			;;
	esac
	case "$F" in
		*dirt*|*terrain*|*old*)
			bounceScale=`echo "$bounceScale - 0.25" | bc -l`
			shaderHead="$shaderHead	surfaceparm dust$LF"
			;;
	esac

	shaderDiffuse="$F"
	if [ -f "$F""_gloss.tga" ] || [ -f "$F""_gloss.jpg" ] || [ -f "$F""_gloss.png" ]; then
		bounceScale=`echo "$bounceScale + 0.25" | bc -l`
	fi

	if [ -f "$F""_qei.tga" ] || [ -f "$F""_qei.jpg" ] || [ -f "$F""_qei.png" ]; then
		shaderQUI="$F""_qei"
	else
		shaderQUI="$F"
	fi

	if ! $noLightmap; then
		shaderTail="	{$LF		map \$lightmap$LF		rgbGen identity$LF		tcGen lightmap$LF		blendfunc filter$LF	}"
	fi
	case "$bounceScale" in
		1|1.0|1.00)
			;;
		*)
			shaderHead="$shaderHead	q3map_bouncescale $bounceScale$LF"
			;;
	esac

	shaderName="`echo "$F" | cut -d / -f 1-2`/`echo "$F" | cut -d / -f 3`-`echo "$F" | cut -d / -f 4`"
	echo "$shaderString$LF$LF" | sed -e "
		s,%shader_name%,$shaderName,g;
		s,%qei_name%,$shaderQUI,g;
		s,%shader_head%,$shaderHead,g;
		s,%diffuse_map%,$shaderDiffuse,g;
		s,%diffuse_map_extra%,$diffuseExtra,g;
		s,%shader_tail%,$shaderTail,g;
	" >&3
done
