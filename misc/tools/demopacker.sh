#!/bin/sh

xonotic=$1; shift
demo=$1; shift
# rest: command line options to use

demobase=${demo##*/}

cp "$demo" data/"$demobase"

USE_RLWRAP=no strace -qo strace.txt -f -e trace=open ./all run -nohome -readonly -forceqmenu -window -nocrashdialog "$@" -demo "$demobase"

allfiles()
{
	<strace.txt \
		grep '^[0-9]*  *open("' strace.txt |\
		cut -d '"' -f 2 |\
		grep '^data/[^/]*\.pk3dir/' |\
		sort -u
}
allfiles=`allfiles`

include_as()
{
	mkdir -p "output/$1"
	rmdir "output/$1"
	cat > "output/$1"
}

rm -rf output

while [ -n "$allfiles" ]; do
	l=$allfiles
	allfiles=
	for f in $l; do
		[ -f "$f" ] || continue
		fn=${f#*/*/}
		case "$f" in
			*/csprogs.dat)
				# spam, skip it
				;;
			*/unifont-*.ttf)
				# spam, skip it
				;;
			*.mapinfo)
				<"$f" include_as "$fn"

				# also include the map pk3 content
				n=${f##*/}
				n=${n%.*}
				rm -rf data/temp-$n
				mkdir data/temp-$n
				(
					cd data/temp-$n
					unzip ../../data/"$n"-*.pk3
				)
				allfiles=$allfiles" `find data/temp-$n -type f`"
				;;
			*)
				<"$f" include_as "$fn"
				;;
		esac
	done
done

export do_jpeg=true
export do_jpeg_if_not_dds=false
export jpeg_qual_rgb=70
export jpeg_qual_a=90
export do_dds=false
export do_ogg=true
export ogg_ogg=true
export ogg_qual=1
export del_src=true
export git_src_repo=
cd output
find . -type f -print0 | xargs -0 ../misc/tools/cached-converter.sh
cd ..
mv data/"$demobase" output/
echo "-xonotic -nohome -readonly -forceqmenu +bind ESCAPE quit $* -demo $demobase" > output/darkplaces.opt
rm output.pk3
( cd output && 7za a -tzip -mx=9 ../output.pk3 . )
cp "$xonotic" output.exe
cat output.pk3 >> output.exe
