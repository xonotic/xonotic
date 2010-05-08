;Converts .png image files to .tga.
;Input: fileIN, fileOUT, grayscale (0=no, 1=yes), alpha 0.5 (0=no, 1=yes)

(define (png-tga fileIn fileOut gray alpha)
	(let*
		(
			(image (car (gimp-file-load 1 fileIn fileIn)))
			(layer (car (gimp-image-get-active-layer image)))
		)

		(if (= gray 1)
			(gimp-desaturate-full layer 1)
		)

		(if (= alpha 1)
			(gimp-layer-set-opacity layer 50.0)
		)

		(set! layer (car (gimp-image-merge-visible-layers image 1)))
		(file-tga-save 1 image layer fileOut fileOut 1 0)
		(gimp-image-delete image)
	)
)

