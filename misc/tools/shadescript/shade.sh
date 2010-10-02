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
			shaderHead="$shaderHead	surfaceparm trans\n	surfaceparm water\n	qer_trans 20\n"
			;;
		*slime*)
			noLightmap=true
			isLiquid=true
			shaderHead="$shaderHead	surfaceparm trans\n	surfaceparm slime\n	qer_trans 20\n"
			;;
		*lava*)
			noLightmap=true
			isLiquid=true
			shaderHead="$shaderHead	surfaceparm trans\n	surfaceparm lava\n	qer_trans 20\n"
			;;
		*glass*)
			noLightmap=true
			shaderHead="$shaderHead	surfaceparm trans\n"
			diffuseExtra="$diffuseExtra		blendfunc add\n"
			;;
		*metal*)
			bounceScale=`echo "$bounceScale + 0.25" | bc -l`
			shaderHead="$shaderHead	surfaceparm metalsteps\n"
			;;
	esac

	# what is it used for
	case "$F" in
		*grate*)
			bounceScale=`echo "$bounceScale + 0.25" | bc -l`
			shaderHead="$shaderHead	surfaceparm trans\n"
			diffuseExtra="$diffuseExtra		blendfunc blend\n"
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
			shaderHead="$shaderHead	surfaceparm dust\n"
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
		shaderTail="	{\n		map \$lightmap\n		rgbGen identity\n		tcGen lightmap\n		blendfunc filter\n	}"
	fi
	case "$bounceScale" in
		1|1.0|1.00)
			;;
		*)
			shaderHead="$shaderHead	q3map_bouncescale $bounceScale\n"
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
