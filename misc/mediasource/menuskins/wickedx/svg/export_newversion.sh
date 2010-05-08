#!/bin/bash
#Requires vi, Inkscape, Gimp and ~/.gimp*/scripts/png-tga.scm
#Used when the version number in background_l2.svg is changed.
#Exports png images from background_l2.svg of all color versions,
#converts them to tga and copyies them into wickedx folders in /tga

echo "Creating folders ..."
if [ ! -d tga ]
then
   mkdir tga
fi

cd tga

if [ ! -d wickedx ]
then
   mkdir wickedx
fi

if [ ! -d wickedx_blue ]
then
   mkdir wickedx_blue
fi

if [ ! -d wickedx_green ]
then
   mkdir wickedx_green
fi

if [ ! -d wickedx_magenta ]
then
   mkdir wickedx_magenta
fi

if [ ! -d wickedx_red ]
then
   mkdir wickedx_red
fi

if [ ! -d wickedx_yellow ]
then
   mkdir wickedx_yellow
fi

cd ..

echo "Creating individual color versions of background_l2.svg ..."
cp background_l2.svg background_l2_blue.svg
cp background_l2.svg background_l2_green.svg
cp background_l2.svg background_l2_magenta.svg
cp background_l2.svg background_l2_red.svg
cp background_l2.svg background_l2_yellow.svg

vi -e background_l2_blue.svg <<-EOF
:%s/textures/textures_blue/g
:update
:quit
EOF

vi -e background_l2_green.svg <<-EOF
:%s/textures/textures_green/g
:update
:quit
EOF

vi -e background_l2_magenta.svg <<-EOF
:%s/textures/textures_magenta/g
:update
:quit
EOF

vi -e background_l2_red.svg <<-EOF
:%s/textures/textures_red/g
:update
:quit
EOF

vi -e background_l2_yellow.svg <<-EOF
:%s/textures/textures_yellow/g
:update
:quit
EOF

echo "Exporting png images from svg files..."
inkscape -e tga/background_l2.png -d 90 background_l2.svg
inkscape -e tga/background_l2_blue.png -d 90 background_l2_blue.svg
inkscape -e tga/background_l2_green.png -d 90 background_l2_green.svg
inkscape -e tga/background_l2_magenta.png -d 90 background_l2_magenta.svg
inkscape -e tga/background_l2_red.png -d 90 background_l2_red.svg
inkscape -e tga/background_l2_yellow.png -d 90 background_l2_yellow.svg
rm background_l2_blue.svg
rm background_l2_green.svg
rm background_l2_magenta.svg
rm background_l2_red.svg
rm background_l2_yellow.svg

echo "Converting png to tga..."
#(png-tga fileIn fileOut grayscale alpha0.5)
cd tga
gimp -d -f -i \
-b '(png-tga "background_l2.png" "background_l2.tga" 0 0)' \
-b '(png-tga "background_l2_blue.png" "background_l2_blue.tga" 0 0)' \
-b '(png-tga "background_l2_green.png" "background_l2_green.tga" 0 0)' \
-b '(png-tga "background_l2_magenta.png" "background_l2_magenta.tga" 0 0)' \
-b '(png-tga "background_l2_red.png" "background_l2_red.tga" 0 0)' \
-b '(png-tga "background_l2_yellow.png" "background_l2_yellow.tga" 0 0)' \
-b '(gimp-quit 0)'

echo "Copying tga files to folders and removing temporary files..."
cp background_l2.tga wickedx/background_l2.tga
cp background_l2.tga wickedx/background_ingame.tga
cp background_l2_blue.tga wickedx_blue/background_l2.tga
cp background_l2_blue.tga wickedx_blue/background_ingame.tga
cp background_l2_green.tga wickedx_green/background_l2.tga
cp background_l2_green.tga wickedx_green/background_ingame.tga
cp background_l2_magenta.tga wickedx_magenta/background_l2.tga
cp background_l2_magenta.tga wickedx_magenta/background_ingame.tga
cp background_l2_red.tga wickedx_red/background_l2.tga
cp background_l2_red.tga wickedx_red/background_ingame.tga
cp background_l2_yellow.tga wickedx_yellow/background_l2.tga
cp background_l2_yellow.tga wickedx_yellow/background_ingame.tga

rm background_l2.png
rm background_l2_blue.png
rm background_l2_green.png
rm background_l2_magenta.png
rm background_l2_red.png
rm background_l2_yellow.png
rm background_l2.tga
rm background_l2_blue.tga
rm background_l2_green.tga
rm background_l2_magenta.tga
rm background_l2_red.tga
rm background_l2_yellow.tga

echo "Export complete."
