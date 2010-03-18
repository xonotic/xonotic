#!/bin/sh

# usage: ./nexbrand.sh "2.0.1 RC 1" rc1
#   writes "2.0.1 RC 1" on rc1.tga
# NOTE: unfortunately requires X-server (otherwise file-tga-save won't work... no joke)

# roughly based on Spencer Kimball's "Glowing Hot" effect, included with GIMP

version=$1
versiontag=$2

gimp -i -b - <<EOF

(define (nexuiz-brand-image img text size font)
	(let*(
			(border (/ size 4))
			(text-layer (car (gimp-text-fontname img -1 0 0 text border TRUE size PIXELS font)))
			(grow (/ size 4))
			(feather1 (/ size 3))
			(feather2 (/ size 7))
			(feather3 (/ size 10))
			(width (car (gimp-drawable-width text-layer)))
			(height (car (gimp-drawable-height text-layer)))
			(posx (- (car (gimp-drawable-offsets text-layer))))
			(posy (- (cadr (gimp-drawable-offsets text-layer))))
			(glow-layer (car (gimp-layer-copy text-layer TRUE)))
		)
		(gimp-layer-resize text-layer width (+ 36 height) 0 0)
		(gimp-image-resize img width (+ 36 height) 0 0)
		(gimp-image-resize-to-layers img)
		(gimp-image-add-layer img glow-layer 1)
		(gimp-layer-translate glow-layer posx posy)
		(gimp-selection-none img)
		(gimp-layer-set-preserve-trans text-layer TRUE)
		(gimp-context-set-background '(0 0 0))
		(gimp-edit-fill text-layer BACKGROUND-FILL)
		(gimp-selection-layer-alpha text-layer)
		(gimp-selection-feather img feather1)
		(gimp-context-set-background '(221 0 0))
		(gimp-edit-fill glow-layer BACKGROUND-FILL)
		(gimp-edit-fill glow-layer BACKGROUND-FILL)
		(gimp-edit-fill glow-layer BACKGROUND-FILL)
		(gimp-selection-layer-alpha text-layer)
		(gimp-selection-feather img feather2)
		(gimp-context-set-background '(232 217 18))
		(gimp-edit-fill glow-layer BACKGROUND-FILL)
		(gimp-edit-fill glow-layer BACKGROUND-FILL)
		(gimp-selection-layer-alpha text-layer)
		(gimp-selection-feather img feather3)
		(gimp-context-set-background '(255 255 255))
		(gimp-edit-fill glow-layer BACKGROUND-FILL)
		(gimp-selection-none img)
	)
)

(let*(
		(img (car (gimp-image-new 256 256 RGB)))
	)
	(gimp-image-undo-disable img)
	(nexuiz-brand-image img "$version" 24 "Bitstream Vera Sans Bold")
	(gimp-image-merge-visible-layers img 1)
	(file-tga-save RUN-NONINTERACTIVE img (car (gimp-image-active-drawable img)) "$versiontag.tga" "$versiontag.tga" 1 1)
	(gimp-quit 0)
)

EOF
