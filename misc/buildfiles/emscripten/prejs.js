//current command in ascii decimal
let currentcmd = [0,0,0] 
let cmditerate = 0
console.log("Run Terminal Commands by running cmd(\"command to run here\")")
cmd = function(input){
    for (let i = 0; i < input.length; i++){
        
        currentcmd[i] = input.charCodeAt(i)

    }
    return 0
}
Module['preInit'] = function(){FS.mount(IDBFS,{},"/")}
Module['arguments'] = ["-xonotic"]
//pipes output to console
Module['print'] = function(text){console.log(text); FS.syncfs()}
Module['preRun'] = function(){
    function stdin(){
    //if current command is default, it just returns 0, code for null
    if(currentcmd == [0,0,0]){
        return 0
    }
    //it iterates through the cmd
    cmditerate++;
    if(cmditerate - 1 > currentcmd.length - 1) {currentcmd = [0,0,0]; return 10}
    return currentcmd[cmditerate - 1]

    }; 
    var stdout = null;
    var stderr = null; 
    FS.init(stdin,stdout,stderr);
}