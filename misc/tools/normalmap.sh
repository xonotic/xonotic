#!/bin/sh

# usage: ./bump2norm.sh foo_bump.tga foo_norm.tga
# NOTE: unfortunately requires X-server (otherwise file-tga-save won't work... no joke)

in=$1
out=$2

# env variables you can set:
# filter:
#   Filter type (0 = 4 sample, 1 = sobel 3x3, 2 = sobel 5x5, 3 = prewitt 3x3, 4 = prewitt 5x5, 5-8 = 3x3,5x5,7x7,9x9)
# minz:
#   Minimun Z (0 to 1)
# scale:
#   Scale (>0)
# conv:
#   Conversion (0 = none, 1 = Biased RGB, 2 = Red, 3 = Green, 4 = Blue, 5 = Max RGB, 6 = Min RGB, 7 = Colorspace)
: ${filter:=0}
: ${minz:=0}
: ${scale:=1}
: ${conv:=0}

gimp -i -b - <<EOF

(let*(
		(img (car (gimp-file-load RUN-NONINTERACTIVE "$in" "$in")))
		(drawable (car (gimp-image-active-drawable img)))
		(layer (car (gimp-image-get-active-layer img)))
	)
	(gimp-layer-add-alpha layer)
	(plug-in-normalmap RUN-NONINTERACTIVE img drawable $filter $minz $scale 1 0 1 $conv 0 0 1 0 1 layer)
	(file-tga-save RUN-NONINTERACTIVE img drawable "$out" "$out" 1 1)
	(gimp-quit 0)
)

EOF
