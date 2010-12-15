handle SIGHUP nostop print pass
handle SIGINT nostop print pass
handle SIGCONT nostop print pass
handle SIGSTOP nostop print pass
handle SIGTSTP nostop print pass
handle SIGTRAP nostop print nopass
run
set pagination off
echo \n\nIf the following commands show errors, that can be ignored:\n
bt full
generate-core-file xonotic.core
