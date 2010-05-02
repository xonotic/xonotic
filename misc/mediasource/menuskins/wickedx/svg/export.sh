#!/bin/bash
#Requires Inkscape, Gimp and ~/.gimp*/scripts/png-tga.scm
#Exports png images from svg files (to /tga) and converts them to tga. 

if [ ! -d tga ]
then
   mkdir tga
fi

echo "Exporting png images from svg files..."
inkscape -e tga/background_l2.png -d 90 background_l2.svg
inkscape -e tga/bigbutton_c.png -d 90 bigbutton_c.svg
inkscape -e tga/bigbutton_f.png -d 90 bigbutton_f.svg
inkscape -e tga/bigbutton_n.png -d 90 bigbutton_n.svg
inkscape -e tga/border.png -d 90 border.svg
inkscape -e tga/button_c.png -d 45 button_c.svg
inkscape -e tga/button_f.png -d 45 button_f.svg
inkscape -e tga/button_n.png -d 45 button_n.svg
inkscape -e tga/charmapbutton.png -d 45 charmapbutton.svg
inkscape -e tga/checkbox_n0.png -d 45 checkbox_n0.svg
inkscape -e tga/checkbox_n1.png -d 45 checkbox_n1.svg
inkscape -e tga/checkmark.png -d 45 checkmark.svg
inkscape -e tga/closebutton_c.png -d 90 closebutton_c.svg
inkscape -e tga/closebutton_f.png -d 90 closebutton_f.svg
inkscape -e tga/closebutton_n.png -d 90 closebutton_n.svg
inkscape -e tga/color.png -d 45 color.svg
inkscape -e tga/crosshairbutton_c.png -d 45 crosshairbutton_c.svg
inkscape -e tga/crosshairbutton_f.png -d 45 crosshairbutton_f.svg
inkscape -e tga/cursor.png -d 45 cursor.svg
inkscape -e tga/inputbox_f.png -d 45 inputbox_f.svg
inkscape -e tga/inputbox_n.png -d 45 inputbox_n.svg
inkscape -e tga/radiobutton_c.png -d 45 radiobutton_c.svg
inkscape -e tga/radiobutton_f.png -d 45 radiobutton_f.svg
inkscape -e tga/radiobutton_n.png -d 45 radiobutton_n.svg
inkscape -e tga/scrollbar_n.png -d 45 scrollbar_n.svg
inkscape -e tga/scrollbar_s.png -d 45 scrollbar_s.svg
inkscape -e tga/slider_n.png -d 45 slider_n.svg
inkscape -e tga/slider_s.png -d 45 slider_s.svg
inkscape -e tga/tooltip.png -d 45 tooltip.svg

cd tga
echo "Converting png to tga..."
#(png-tga fileIn fileOut grayscale alpha0.5)
gimp -d -f -i \
-b '(png-tga "background_l2.png" "background_l2.tga" 0 0)' \
-b '(png-tga "background_l2.png" "background_ingame.tga" 0 0)' \
-b '(png-tga "bigbutton_c.png" "bigbutton_c.tga" 0 0)' \
-b '(png-tga "bigbutton_c.png" "bigbuttongray_c.tga" 1 0)' \
-b '(png-tga "bigbutton_f.png" "bigbutton_f.tga" 0 0)' \
-b '(png-tga "bigbutton_f.png" "bigbuttongray_f.tga" 1 0)' \
-b '(png-tga "bigbutton_n.png" "bigbutton_n.tga" 0 0)' \
-b '(png-tga "bigbutton_n.png" "bigbutton_d.tga" 0 1)' \
-b '(png-tga "bigbutton_n.png" "bigbuttongray_n.tga" 1 0)' \
-b '(png-tga "bigbutton_n.png" "bigbuttongray_d.tga" 1 1)' \
-b '(png-tga "border.png" "border.tga" 0 0)' \
-b '(png-tga "button_c.png" "button_c.tga" 0 0)' \
-b '(png-tga "button_c.png" "buttongray_c.tga" 1 0)' \
-b '(png-tga "button_f.png" "button_f.tga" 0 0)' \
-b '(png-tga "button_f.png" "buttongray_f.tga" 1 0)' \
-b '(png-tga "button_n.png" "button_n.tga" 0 0)' \
-b '(png-tga "button_n.png" "button_d.tga" 0 1)' \
-b '(png-tga "button_n.png" "buttongray_n.tga" 1 0)' \
-b '(png-tga "button_n.png" "buttongray_d.tga" 1 1)' \
-b '(png-tga "charmapbutton.png" "charmapbutton.tga" 0 0)' \
-b '(png-tga "checkbox_n0.png" "checkbox_c0.tga" 0 0)' \
-b '(png-tga "checkbox_n0.png" "checkbox_d0.tga" 0 1)' \
-b '(png-tga "checkbox_n0.png" "checkbox_f0.tga" 0 0)' \
-b '(png-tga "checkbox_n0.png" "checkbox_n0.tga" 0 0)' \
-b '(png-tga "checkbox_n1.png" "checkbox_c1.tga" 0 0)' \
-b '(png-tga "checkbox_n1.png" "checkbox_d1.tga" 0 1)' \
-b '(png-tga "checkbox_n1.png" "checkbox_f1.tga" 0 0)' \
-b '(png-tga "checkbox_n1.png" "checkbox_n1.tga" 0 0)' \
-b '(png-tga "checkmark.png" "checkmark.tga" 0 0)' \
-b '(png-tga "closebutton_c.png" "closebutton_c.tga" 0 0)' \
-b '(png-tga "closebutton_f.png" "closebutton_f.tga" 0 0)' \
-b '(png-tga "closebutton_n.png" "closebutton_n.tga" 0 0)' \
-b '(png-tga "color.png" "color.tga" 0 0)' \
-b '(png-tga "crosshairbutton_c.png" "crosshairbutton_c.tga" 0 0)' \
-b '(png-tga "crosshairbutton_c.png" "colorbutton_c.tga" 0 0)' \
-b '(png-tga "crosshairbutton_f.png" "crosshairbutton_f.tga" 0 0)' \
-b '(png-tga "crosshairbutton_f.png" "colorbutton_f.tga" 0 0)' \
-b '(png-tga "cursor.png" "cursor.tga" 0 0)' \
-b '(png-tga "inputbox_f.png" "inputbox_f.tga" 0 0)' \
-b '(png-tga "inputbox_n.png" "inputbox_n.tga" 0 0)' \
-b '(png-tga "radiobutton_c.png" "radiobutton_c0.tga" 0 0)' \
-b '(png-tga "radiobutton_c.png" "radiobutton_c1.tga" 0 0)' \
-b '(png-tga "radiobutton_c.png" "radiobutton_d1.tga" 0 1)' \
-b '(png-tga "radiobutton_c.png" "radiobutton_f1.tga" 0 0)' \
-b '(png-tga "radiobutton_c.png" "radiobutton_n1.tga" 0 0)' \
-b '(png-tga "radiobutton_f.png" "radiobutton_f0.tga" 0 0)' \
-b '(png-tga "radiobutton_n.png" "radiobutton_d0.tga" 0 1)' \
-b '(png-tga "radiobutton_n.png" "radiobutton_n0.tga" 0 0)' \
-b '(png-tga "scrollbar_n.png" "scrollbar_c.tga" 0 0)' \
-b '(png-tga "scrollbar_n.png" "scrollbar_f.tga" 0 0)' \
-b '(png-tga "scrollbar_n.png" "scrollbar_n.tga" 0 0)' \
-b '(png-tga "scrollbar_s.png" "scrollbar_s.tga" 0 0)' \
-b '(png-tga "slider_n.png" "slider_c.tga" 0 0)' \
-b '(png-tga "slider_n.png" "slider_d.tga" 0 1)' \
-b '(png-tga "slider_n.png" "slider_f.tga" 0 0)' \
-b '(png-tga "slider_n.png" "slider_n.tga" 0 0)' \
-b '(png-tga "slider_s.png" "slider_s.tga" 0 0)' \
-b '(png-tga "tooltip.png" "tooltip.tga" 0 0)' \
-b '(gimp-quit 0)'

echo "Removing png files from /tga ..."
rm background_l2.png
rm bigbutton_c.png
rm bigbutton_f.png
rm bigbutton_n.png
rm border.png
rm button_c.png
rm button_f.png
rm button_n.png
rm charmapbutton.png
rm checkbox_n0.png
rm checkbox_n1.png
rm checkmark.png
rm closebutton_c.png
rm closebutton_f.png
rm closebutton_n.png
rm color.png
rm crosshairbutton_c.png
rm crosshairbutton_f.png
rm cursor.png
rm inputbox_f.png
rm inputbox_n.png
rm radiobutton_c.png
rm radiobutton_f.png
rm radiobutton_n.png
rm scrollbar_n.png
rm scrollbar_s.png
rm slider_n.png
rm slider_s.png
rm tooltip.png

echo "Export complete."
