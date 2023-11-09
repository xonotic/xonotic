This subdirectory contains scripts and a config file that can be used
to start a dedicated Xonotic server on Linux, Mac and Windows systems
and also some tools that help with maintaining your server.

You will need to copy the right server_* script for your system into
your Xonotic main directory, where the normal binaries are. 
You should then COPY the provided server.cfg to user's game directory
(Linux: '~/.xonotic/data'
 Mac: '~/Library/Application Support/xonotic/data'
 Windows: '%UserProfile%\Saved Games\xonotic\data')

After you have setup everything and have adjusted the config file 
you can start the server by running the server script.

An important thing is to make sure that your firewall allows
players to connect to your server.  This typically means you will have
to open or forward the port (see the line that sets the variable port
in your server.cfg for the right port number, default is 26000) to the
computer running your server.  How to do this does depend on your
computer and network setup.

If you want to run a dedicated server and a client on the the same
machine, they need to have session ids that differ from each other.
To start the server with a custom session id (different from the
default id that the client uses) run it with the argument "-sessionid"
followed by a session id of your choice.
Example: server_linux.sh -sessionid server

If you plan to install custom maps on your server you should read the
file Xonotic/Docs/mapdownload.txt to learn how to setup automatic map
downloads.

In case you want to rename the server.cfg file (e.g. because you want
to run several servers on one machine), you have to edit the script and
change the name there too.

A very useful tool for running and controlling a server is the
application 'gnu screen'.  It should be available for all usual
operating systems.  You can find some hints about its usage here:
http://www.gnu.org/software/screen/manual/screen.html

The options in the config file are only the most interesting and
important ones.  You can get a list of all available commands and
variables with 'cmdlist' and 'cvarlist' in the server console.

rcon.pl is a perl script that implements rcon which can be used to
remotely control your server.  Refer to the file itself for usage.

rcon2irc is a Xonotic server to irc gateway.  It allows you to watch
and communicate with active players on your server via irc.
Refer to rcon2irc.txt for usage and instructions.

help.cfg is a Xonotic config file providing a simple help message
system.  It prints all the messages from a list, one after the other
with an configureable delay between them.  Great to provide beginners
with some hints.
