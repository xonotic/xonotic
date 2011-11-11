Windows users:
Double click update-xonotic.bat and wait for the download to complete.

Linux/OSX users:
Change to this directory in a terminal, then run ./update-xonotic.sh and wait
for the download to complete.

Redoing this step at a later time will only download the changes since last
time. Note that any changes inside the Xonotic directory will be overwritten.
Do your changes in the directory that has the config.cfg file!

Secret trick: if you create a directory Xonotic-low in this directory before
running the updater (or later, if you rename the Xonotic directory the updater
created to Xonotic-low), this script will download the low version of Xonotic.
If you create a directory Xonotic-high in this directory before running the
updater (or later, if you rename the Xonotic directory the updater created to
Xonotic-high), it will download the HQ version! If none of the two exists, it
will download regular Xonotic. Only one version of the game can be managed by
this script.
