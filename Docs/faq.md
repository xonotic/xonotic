---
author: Antibody
date: 2010-05-30 14:50:21+00:00
type: faq
title: FAQ
aliases:
- /the-game/faq
---

# Xonotic FAQs

<a name="install"></a>
## How do I install Xonotic?

**There is no need to install Xonotic!** The zip file you downloaded from the homepage has everything. All binaries to run the game on Linux, Windows and macOS are inside of it. Just unzip the archive and run the appropriate executable for your OS.

For example, on Windows or macOS you can start the game by double-clicking the Xonotic logo. On Linux you can run xonotic-linux-sdl.sh.

## Is there a Debian package available?

Unfortunately, Xonotic is not in the Debian repositories yet. You can check the status of the bug report [here](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=646377). If you can help us expedite this process, please contact us!

## How do you pronounce the name Xonotic?

There are two pronunciations, depending on where you live.

US people are more likely to pronounce it : _zone + otic_  
European people are more likely to pronounce it : _kso + notic_


## How and why did you choose the logo?

The logo design process took about a week, with a handful of people contributing designs, and constantly adjusting those designs based on feedback.

The phoenix image of the logo obviously refers to the concept of "rising from the ashes".

Another aspect of the logo is the center ring, which has some similarities to the Quake logo; it has a fatter bottom edge and thinner top edge, though quake didn't use a complete ring shape. This is intended as a pay of respect to the Quake origins of the game, as the Darkplaces engine was originally based on the Quake 1 engine.

# Troubleshooting

## I can't launch Xonotic on Linux

The most likely reason Xonotic won't start is that you've accidentally launched the dedicated server (e.g. `xonotic-linux64-dedicated`) which runs silently in the background. It shares a lockfile (`~/.xonotic/lock`) with the normal executable and prevents it from launching. Kill any processes which have xonotic in the name (you might also need to remove the lockfile manually) and try again.

Use the executable or script with "sdl" in the name to launch Xonotic.

## I can't launch Xonotic on macOS Sierra or later

(Full error message: "You have reached this menu due to missing or unlocatable content/data. You may consider adding -basedir /path/to/game to your launch commandline.")

In the Finder, control-click the app icon, then choose Open from the shortcut menu. Click Open on the dialog.

This happens because Xonotic is not signed using an Apple developer key.

## When I join a server or after a map change I see nothing but a black screen, but I can still move and shoot

This is probably because you don't have the map that's running on the server or it didn't download correctly. Try clearing your _dlcache_ (in [\<your config folder\>](#config)/data/dlcache) and restarting Xonotic.

For Linux users: you need to have libcurl installed, otherwise you won't be able to download any maps. libcurl should be available in any Linux distribution, just search for "libcurl" and install it in your distribution's package manager.

## When I start Xonotic all I see is a black screen or a black screen with some checkered squares

This happens when the engine can't load the data*.pk3 file or has trouble to initialize OpenGL. The reasons could be:

  * You unpacked the zip file without folder names, see [How do I install Xonotic?]({{< relref "#how-do-i-install-xonotic" >}})
  * On Linux: the current directory is not your Xonotic/ folder.
  * On Mac: you tried to extract and move the files from a Xonotic update and it deleted the old files. When using the mac GUI please be sure to move only the files not the folders as that will delete the old files or use the mv console command which will not delete the old files.
  * The engine could not initialize OpenGL. Please install the latest drivers for your graphic card. You will probably find one for your card there: [intel](http://intel.com), [AMD](http://amd.com), [nvidia](http://nvidia.com).
  * Your download might be corrupted, please download Xonotic again.

## Using Linux I only see the map but no players and items

This happens when the engine has trouble initializing OpenGL. The reasons could be:

  * The engine could not initialize OpenGL. Please install the latest drivers for your graphic card. You will probably find one for your card there: [intel](http://intel.com), [AMD](http://amd.com), [nvidia](http://nvidia.com).
  * You do not have permissions needed for 3d acceleration. Usually you need to add yourself to the group video, you can do that via console as root like this: `usermod -a -G video YOURUSERNAME`. You need to logoff/in afterwards.

## When I start Xonotic my screen is flickering

This is known to happen on Windows with Intel graphic chips and is a bug in the graphics drivers. A workaround is to set Flip-Policiy to blit. Open the control panel, there should be an icon called Intel(R) GMA driver (or something like that), double click it. Click on 3D Settings to find the screen with those settings.

## How can I speed up my frame rate?

You can choose predefined performance settings in the Settings->Video menu or you can enable/disable single features. The greatest performance boost can be achieved by turning off dynamic lights and shadows in the Settings->Effects menu. Bloom is also quite resource intensive. Other fps boots include disabling Deluxemapping and Coronas. On older graphics cards or on-board/notebook chips with little video ram you can try to lower the texture quality in the Settings->Video menu. Some graphic cards (mostly ATI or quite old cards) run A LOT faster if you disable the Vertex Buffer Objects in the Settings->Video menu. An other thing that can greatly help on such cards is to disable the OpenGL 2.0 Shaders. Having that option enabled is faster on most cards however, that is why both are active by default.

If none of that helps, you can try compiling Xonotic from [source](http://gitlab.com/xonotic/xonotic/wikis/Repository_Access).

## The sound is broken, it crackles and stutters

Adding the command line options -sndspeed 48000 and/or -sndstereo may help on some systems (on Linux, Mac, Windows).

## Mouse is too slow and sensitivity is at top on Mac

Mac: The default mouse acceleration on Mac is very high and strange. The Xonotic defaults work fine with it but some mouse drivers seem to 'correct' the mouse acceleration and conflict with the Xonotic defaults. Try to **disable the option Disable system mouse acceleration** in the Settings->Input menu. Or the same via console: `apple_mouse_noaccel 0; vid_restart` ([How do I open the console?]({{< relref "#how-do-i-open-the-console" >}}))

## I can't switch to 32 bit color depth (on Windows)

Check if your desktop color depth is set to 32 bits per pixel. If it's just set to 16, Xonotic can't switch to 32 bit mode.

## How to report crashes and bugs?

Use our [issue tracker](http://gitlab.com/xonotic/xonotic-data.pk3dir/issues) on Gitlab.

If you want to investigate crashes further:

On Linux: In a terminal, `cd` into your Xonotic installation directory, execute `catchsegv ./xonotic-linux64-sdl -condebug -developer > crash.txt 2>&1` and give the file crash.txt to the developers.

On Windows: Click Start->Run, and enter drwtsn32, click Ok in the next window, run Xonotic and wait for the crash. Then go to C:\Documents and Settings\All Users\Application Data\Microsoft\Dr Watson there should be a file called "drwtsn32.log", give that file along with the engine's build date to the developers. You'll see that date when you open the ingame console (How do I open the console?). Note that some folders of that path may be hidden or have a translated name if you're using a non-english windows.

## Where can I get more help?

Visit the official Xonotic [forum](http://forums.xonotic.org/), there is a support and bug report area, or [ask in chat](http://xonotic.org/chat).

# General questions

<a name="config"></a>
## Where are the configuration files located?

  * Linux: ~/.xonotic
  * Windows: C:\\Users\\\<your_user_name\>\\Saved Games\\xonotic
  * Mac: ~/Library/Application Support/xonotic
      * Library might be hidden on Mac so Finder won't display it

## What is the difference between the config and install directories?

The install directory is what you get when you unzip the downloaded file. We usually call it Xonotic. Since Xonotic (the game) doesn't need installation, Xonotic (the folder) can be anywhere you put it.

The config directory (sometimes called user directory) has a specific [location](#config) depending on your OS but we usually call it ~/.xonotic since most players and devs are on linux. ~/.xonotic contains all your settings and it's where you can put additional maps or assets when experimenting with the game or running your own server.

## How do I install new maps?

Maps usually ship as a .pk3 file. All you have to do is to copy this file to the [\<config folder\>](#config)/data/ directory. To detect the new map, either restart Xonotic or run `fs_rescan` in console.

Map packages that were downloaded from a server when playing on it end up in [\<your config folder\>](#config)/data/dlcache/ and are only used till you exit Xonotic. If you want to play them locally or use them to setup a server of your own you can "accept" the packages by moving them one level up (right next to your config.cfg).

There are multiple [unofficial map repositories](https://gitlab.com/xonotic/xonotic/wikis/Home#unofficial-map-repositories).

## How can I place a shortcut to Xonotic on my Linux desktop?

Use the script xonotic-linux-sdl.sh instead of the binaries. The script will use the correct working directory, and if applicable, select the correct engine binary for your platform.

## How do I open the console?

Press [shift]+[escape]. To close it press [escape]. While playing \` or ^ will also open the console.

## What console commands/variables are there?

An searchable list is available [here](http://www.xonotic.org/tools/cacs/), or you can search in-game using `apropos` in console ([How do I open the console?]({{< relref "#how-do-i-open-the-console" >}})).

## How can I use colors in my nickname and messages?

Colors can be used in nicknames and chat messages via two ways: Either the simple way by typing ^ followed by a number between 0 and 9 or by typing ^x followed by three hexadecimal numbers (0-F) representing red, green and blue components of the color before the text. The second way allows for much more colors. For example if you type ^xF00message the text "message" will be displayed in red color. Simple examples:

| code   | rgb code  | color
|--------|-----------|--------
| ^0     | ^x000     | black
| ^1     | ^xF00     | red
| ^2     | ^x0F0     | green
| ^3     | ^xFF0     | yellow
| ^4     | ^x00F     | blue
| ^5     | ^x0FF     | cyan
| ^6     | ^xF0F     | magenta
| ^7     | ^xFFF     | white
| ^8     |           | half-transparent black
| ^9     | ^x888     | grey
|        | ^x800     | dark red
|        | ^x080     | dark green
|        | ^x880     | dark yellow
|        | ^x008     | dark blue
|        | ^x088     | dark cyan
|        | ^x808     | dark magenta

## How do I watch/record demos?

Demos are recordings of matches that you have played. To automatically record a demo each time you play enable the option Auto record demos in Multiplayer->Media->Demos. Or if you just want to record some matches open the console and type `rec demos/<name>` before playing. That is before starting a game or connecting to a server. The demo file will then be stored in [your config folder](#config)/data/demos/\<name\>.dem. If you downloaded a demo, copy it to [\<your config folder\>](#config)/data/demos/. You might have to create this directory if you have never recorded a demo before. To watch demos you can choose a demo file in Multiplayer->Media->Demos and click the Play button. Also you can watch demos typing `ply demos/<name>` in the console ([How do I open the console?]({{< relref "#how-do-i-open-the-console" >}})).

# Server setup

## How do I start a server?

Use the Multiplayer->Create menu to start a listen server. You will always have to play yourself in a listen server. If you want to create a server without being forced to play yourself please take a look at the file readme.txt in the Xonotic/server/ directory where the dedicated server is explained.

## Which ports do I have to open in firewall/forward from my router to run a server?

The default port is 26000 UDP. You can change that in the Multiplayer->Create menu or by starting Xonotic with the parameter `-port <port>` or having a line `port <port>` in the server config file. If you follow the tutorial mentioned above you do not need this command line argument as it will be done in the config file created for the server. To add the command line argument on Windows, create a new shortcut to xonotic.exe or xonotic-dedicated.exe and right click on it. Select properties and `-port <port>` in the "Target:" line. Be sure that the "Start in:" line contains the full path to your Xonotic folder and click "OK". The parameter will be used if you start Xonotic via that new shortcut.

## Is there some kind of rcon?

Yes there is a QuakeWorld compatible rcon. To use it you must enter `rcon_password <password>` in the server console or server config file. The Xonotic client has to set the same password in the same fashion. You can then issue commands with `rcon <command>` if you are connected to the server or will have to set `rcon_address <ip/hostname>` or `rcon_address <ip/hostname>:<port>` to point to the server. There are also external rcon tools but make sure you use a QW compatible rcon tool.

## How can I kick people who are using special characters in their names?

Enter status at the server console. You will see a list of all players. In front of their names you will see a number (the player id). You can kick the player you don't like with `kick # <player id> <reason>` (notice the space after #).

# Nexuiz Related FAQs

## What prompted the split from Nexuiz?

**Lee Vermeulen**, the [Nexuiz project](http://alientrap.org/nexuiz) founder, decided to license the Nexuiz code (with **LordHavoc** licensing the [Darkplaces engine](http://icculus.org/twilight/darkplaces/)) to a new game development company named [Illfonic](http://illfonic.com) so that they could develop a closed-source version for the PS3. As part of this deal, IllFonic acquired the rights to use the name Nexuiz along with the domain nexuiz.com, and are under no obligation to contribute code back to the open-source Nexuiz project (and have stated that they have no intention of doing so).

When this was announced, the response from the Nexuiz community was overwhelming negative, even among the development team and main contributors. Vermeulen had not actively participated in the project for several years and all development had been done by the community. Most members have expressed a sense of betrayal and cited the project as an example of [mushroom management](http://en.wikipedia.org/wiki/Mushroom_management). Vermeulen essentially cashed in on the hard work of others and sold the code, name and reputation that they had built up over years without him.

Despite attempts to [reason with IllFonic](https://web.archive.org/web/20101212165111/http://alientrap.org/forum/viewtopic.php?f=4&t=6079), they have refused to change the name of their project to a derivative name even though they have directly stated that their "version" of Nexuiz is a completely different game. The hijacking of the Nexuiz project by its absentee founder and IllFonic made it clear that it had no future as it stood and thus the community left to found **Xonotic**.

It should also be noted that IllFonic's code may be in violation of the GPL as most contributors to the Nexuiz codebase have not relicensed their work for inclusion in a closed-source project. This has been another source of outrage for many.

**Update:** The GPL concerns have been cleared up by a recent [interview with LordHavoc](http://games.slashdot.org/story/10/03/24/070234/DarkPlaces-Dev-Forest-Hale-Corrects-Nexuiz-GPL-Stance).

## Was a compromise attempted?

Yes, many in the Nexuiz community tried to [reach a compromise](http://alientrap.org/forum/viewtopic.php?f=4&t=6079), such as having Illfonic contribute some artwork and/or gamecode back to Nexuiz GPL and for them to use a derivative name for their project, e.g. "Nexuiz Reloaded". <del>Illfonic [flatly refused](https://web.archive.org/web/20101212220555/http://alientrap.org/forum/viewtopic.php?p=76108&f=7) all such suggestions.</del> This, along with the clear stance that Alientrap has taken on this issue, made it clear that no compromise could be reached.

**Update** It has been clarified that, despite some of misleading wording in previous communication, Illfonic will be contributing _some_ of the game code back to Nexuiz GPL, mainly having to do with bandwidth improvements and animation blending.

## Do you despise Vermeulen, LordHavoc or Illfonic?

**No!** Without the past work of Vermeulen and LordHavoc, we would not have the game that we enjoy today. We wish them the best of luck in their endeavors. We hope Illfonic's Nexuiz on PS3 is successful. We simply have a difference of opinion on project management and the result is going to be very positive; We're forming a game project that matches what we wanted out of Nexuiz all along.
