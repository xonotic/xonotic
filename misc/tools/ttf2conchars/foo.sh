#!/bin/sh

# assumes gfx is a symlink to Nexuiz's gfx dir
if ! [ -e "gfx/conchars.tga" ]; then
	echo "Symlink your Nexuiz gfx dir to gfx in this folder."
	echo "Then retry."
	exit 1
fi

set -ex
gcc -Wall -Wextra ttf2conchars.c `sdl-config --cflags --libs` -lSDL_ttf -lSDL_image -ggdb3
./a.out gfx/conchars.tga 0 56 64 gfx/vera-sans.tga /usr/share/fonts/truetype/ttf-bitstream-vera/VeraBd.ttf "" "" 1 0.08 0.000000000000001
./a.out gfx/conchars.tga 0 56 64 gfx/vera-sans-big.tga /usr/share/fonts/truetype/ttf-bitstream-vera/VeraBd.ttf "" "" 1 0.28  0.000000000000001
display gfx/vera-sans-big.tga
