#!/bin/sh

# Script to sync the "tos.txt" file on the web host with the version currently in git. 
# Run this as root from the /var/www/update.xonotic.org directory.

set -e

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games"
cd /var/www/update.xonotic.org/HTML

rm -f tos.txt
wget -qO tos.txt "https://gitlab.com/xonotic/xonotic/-/raw/master/misc/infrastructure/tos.txt"
