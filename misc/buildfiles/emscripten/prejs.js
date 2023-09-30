//current command in ascii decimal
let currentcmd = [0,0,0] 
let cmditerate = 0
runcmd = function() {}
Module['arguments'] = "-xonotic"
Module['preRun'] = function(){
    function stdin(){
    //if current command is default, it just returns 0, code for null
    if(currentcmd == [0,0,0]){
        return 0
    }
    //it iterates through the cmd
    cmditerate = cmditerate + 1;
    if(cmditerate - 1 > currentcmd.length - 1) {currentcmd = [0,0,0]; return 0}
    return currentcmd[cmditerate - 1]

    }; 
    var stdout = null; 
    var stderr = null; 
    FS.init(stdin,stdout,stderr);
}