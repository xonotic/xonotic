//current command in ascii decimal
let currentcmd = [0,0,0] 
let currentfile = "";
const sleep = ms => new Promise(r => setTimeout(r,ms));

let isready = function(){
    if(FS.analyzePath("/save/data",false).exists == true){return 1}
    return 0
}
let cmditerate = 0
Module['arguments'] = ["-xonotic","-basedir /save/data"]
Module['print'] = function(text){console.log(text);}
Module['preRun'] = function(){
    
    function stdin(){return 10};
    var stdout = null;
    var stderr = null; 
    FS.init(stdin,stdout,stderr);
    FS.mkdir('/save')
    FS.mount(IDBFS,{},"/save");
    
}