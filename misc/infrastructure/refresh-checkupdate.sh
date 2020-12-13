#!/bin/sh

# Script to sync the "checkupdate.txt" file on the web host with the version currently in git. 
# Run this as root from the /var/www/update.xonotic.org directory.

set -e

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games"
cd /var/www/update.xonotic.org

rm -f checkupdate.txt
wget -qO checkupdate.txt "https://gitlab.com/xonotic/xonotic/-/raw/master/misc/infrastructure/checkupdate.txt"
{
	grep "^V " checkupdate.txt | head -n 1 | cut -c 3-
	grep "^D " checkupdate.txt | head -n 1 | cut -c 3-
	grep "^U " checkupdate.txt | head -n 1 | cut -c 3-
} > checkupdate.txt.oldformat 2>/dev/null
grep '^[^#]' checkupdate.txt > checkupdate.txt.newformat
rm -f checkupdate.txt
if [ x"`wc -l < checkupdate.txt.oldformat`" = x"3" ]; then
	mv checkupdate.txt.newformat HTML/checkupdate.txt
	mv checkupdate.txt.oldformat ../xonotic.org/HTML/dl/checkupdate.txt
else
	echo "checkupdate.txt updating failed. Please debug."
fi

