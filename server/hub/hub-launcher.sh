XON_PROFILE="bitmissile"
XON_DIR="cd $HOME/xonotic/"
XON_COMMON="./all run dedicated +serverconfig"

alias stopxonotic='killall darkplaces-dedicated -s SIGKILL'

alias start-xon-all='xon-ctf-mh && xon-ctf-wa && xon-ka-mh && xon-ka-wa && xon-priv-1 && xon-priv-2 && xon-tourney &&xon-votable'
alias start-xon-bitmissile='xon-ctf-mh && xon-ctf-wa && xon-priv-1'
alias start-xon-godzilla='xon-ctf-mh && xon-votable && xon-priv-1 && xon-tourney'
alias start-xon-srv02='xon-ctf-wa && xon-priv-1'

alias xon-ctf-mh='$XON_DIR && screen -dmS xon-ctf-mh $XON_COMMON sv-dedicated.cfg -sessionid ctf-mh +set \_dedimode \"ctf\" +set \_dedimutator \"minstahook\" +set \_dedidescription \"CTF Instagib+Hook\" +set \_profile \"$XON_PROFILE\"'
alias xon-ctf-wa='$XON_DIR && screen -dmS xon-ctf-wa $XON_COMMON sv-dedicated.cfg -sessionid ctf-wa +set \_dedimode \"ctf\" +set \_dedimutator \"weaponarena\" +set \_dedidescription \"CTF Weaponarena\" +set \_profile \"$XON_PROFILE\"'
alias xon-ka-mh='$XON_DIR && screen -dmS xon-ka-mh $XON_COMMON sv-dedicated.cfg -sessionid ka-mh +set \_dedimode \"keepaway\" +set \_dedimutator \"minstahook\" +set \_dedidescription \"Keepaway Instagib+Hook\" +set \_profile \"$XON_PROFILE\"'
alias xon-ka-wa='$XON_DIR && screen -dmS xon-ka-wa $XON_COMMON sv-dedicated.cfg -sessionid ka-wa +set \_dedimode \"keepaway\" +set \_dedimutator \"weaponarena\" +set \_dedidescription \"Keepaway Weaponarena\" +set \_profile \"$XON_PROFILE\"'
alias xon-priv-1='$XON_DIR && screen -dmS xon-priv-1 $XON_COMMON sv-private-1.cfg -sessionid priv-1 +set \_profile \"$XON_PROFILE\"'
alias xon-priv-2='$XON_DIR && screen -dmS xon-priv-2 $XON_COMMON sv-private-2.cfg -sessionid priv-1 +set \_profile \"$XON_PROFILE\"'
alias xon-tourney='$XON_DIR && screen -dmS xon-tourney $XON_COMMON sv-tourney.cfg -sessionid tourney +set \_profile \"$XON_PROFILE\"'
alias xon-votable='$XON_DIR && screen -dmS xon-votable $XON_COMMON sv-votable.cfg -sessionid votable +set \_profile \"$XON_PROFILE\"'
alias xon-spawnweapons='$XON_DIR && screen -dmS xon-spawnweapons $XON_COMMON sv-spawnweapons.cfg -sessionid spawnweapons +set \_profile \"$XON_PROFILE\"'
