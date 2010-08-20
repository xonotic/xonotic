#!/bin/sh

# usage: ./bump2norm.sh foo_bump.tga foo_norm.tga
# NOTE: unfortunately requires X-server (otherwise file-tga-save won't work... no joke)
# also, alpha channel value 0 is avoided as gimp doesn't save it properly

in=$1
out=$2

# env variables you can set:
# filter:
#   Filter type (0 = 4 sample, 1 = sobel 3x3, 2 = sobel 5x5, 3 = prewitt 3x3, 4 = prewitt 5x5, 5-8 = 3x3,5x5,7x7,9x9)
# minz:
#   Minimun Z (0 to 1)
# scale:
#   Scale (>0)
# heightsource:
#   Height source (0 = average RGB, 1 = alpha channel)
# conv:
#   Conversion (0 = none, 1 = Biased RGB, 2 = Red, 3 = Green, 4 = Blue, 5 = Max RGB, 6 = Min RGB, 7 = Colorspace)
: ${filter:=0}
: ${minz:=0}
: ${scale:=1}
: ${heightsource:=0}
: ${conv:=0}

gimp -i -b - <<EOF

(let*(
		(img (car (gimp-file-load RUN-NONINTERACTIVE "$in" "$in")))
		(drawable (car (gimp-image-active-drawable img)))
		(layer (car (gimp-image-get-active-layer img)))
		(mycurve (cons-array 256 'byte))
		(i 1)
	)
	(gimp-layer-add-alpha layer)
	(aset mycurve 0 1)
	(while (< i 256) (aset mycurve i i) (set! i (+ i 1)))
	(gimp-curves-explicit drawable HISTOGRAM-RED 256 mycurve)
	(gimp-curves-explicit drawable HISTOGRAM-GREEN 256 mycurve)
	(gimp-curves-explicit drawable HISTOGRAM-BLUE 256 mycurve)
	(gimp-curves-explicit drawable HISTOGRAM-ALPHA 256 mycurve)
	(plug-in-normalmap RUN-NONINTERACTIVE img drawable $filter $minz $scale 1 $heightsource 1 $conv 0 0 1 0 1 layer)
	(file-tga-save RUN-NONINTERACTIVE img drawable "$out" "$out" 1 1)
	(gimp-quit 0)
)

EOF
