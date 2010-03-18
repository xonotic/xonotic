#!/bin/sh

set -e

make crc16
crc16=`pwd`/crc16
out=`pwd`/csqcarchive.zip

t=`mktemp -dt csqcarchive.XXXXXX`
cd "$t"

revs()
{
	{
		svn log svn://svn.icculus.org/nexuiz/$1/data/qcsrc/common
		echo
		svn log svn://svn.icculus.org/nexuiz/$1/data/qcsrc/client
	} | {
		while IFS= read -r LINE; do
			if [ "$LINE" = "------------------------------------------------------------------------" ]; then
				read -r REV REST
				case "$REV" in
					r*)
						echo ${REV#r}
						;;
				esac
			fi
		done
	} | sort -n
}

rm -f "$out"
for repo in branches/nexuiz-2.0 trunk; do
	for rev in `revs $repo`; do
		if [ "$rev" -lt 3789 ]; then
			continue
		fi
		svn checkout -r"$rev" svn://svn.icculus.org/nexuiz/$repo/data/qcsrc
		rm -f Makefile csprogs.dat
		wget -OMakefile "http://svn.icculus.org/*checkout*/nexuiz/$repo/data/Makefile?revision=$rev" || continue
		make csprogs.dat || continue
		nm="csprogs.dat.`$crc16 < csprogs.dat`"
		mv csprogs.dat "$nm"
		zip -9r "$out" "$nm"
	done
done
