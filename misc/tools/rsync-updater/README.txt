Windows users:
Double click update-to-{build}.bat and wait for the download to complete.

Linux/OSX users:
Change to this directory in a terminal, then run ./update-to-{build}.sh and wait
for the download to complete.

update-to-autobuild means updating to the latest nightly beta build of Xonotic.
update-to-stable means updating to the latest stable release build of Xonotic.

Redoing this step at a later time will only download the changes since last time.

Note that any changes inside the Xonotic directory will be overwritten.
Do your changes in the directory that has the config.cfg file!
By default those are:
On Windows the "C:\users\%userprofile%\Saved Games\xonotic\data\" folder
On Linux or Mac the "~/.xonotic/data/" directory


Secret trick: if you create any file/directory named "Xonotic-high"
in this directory before running the updater, this script will
download Xonotic with jpeg textures. Otherwise it will
download regular Xonotic. To change from Xonotic-high (jpeg) to regular
create any file/directory named "Xonotic" in this directory and run the script again.
