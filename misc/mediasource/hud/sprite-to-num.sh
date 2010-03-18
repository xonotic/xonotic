<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
<title>Nexuiz - Alientrap Development</title>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<meta name="description" content="Redmine" />
<meta name="keywords" content="issue,bug,tracker" />
<link href="/stylesheets/application.css?1241613297" media="all" rel="stylesheet" type="text/css" />
<script src="/javascripts/prototype.js?1238935462" type="text/javascript"></script>
<script src="/javascripts/effects.js?1238935462" type="text/javascript"></script>
<script src="/javascripts/dragdrop.js?1238935462" type="text/javascript"></script>
<script src="/javascripts/controls.js?1238935462" type="text/javascript"></script>
<script src="/javascripts/application.js?1238935462" type="text/javascript"></script>
<link href="/stylesheets/jstoolbar.css?1238935462" media="screen" rel="stylesheet" type="text/css" />
<!--[if IE]>
    <style type="text/css">
      * html body{ width: expression( document.documentElement.clientWidth < 900 ? '900px' : '100%' ); }
      body {behavior: url(/stylesheets/csshover.htc?1238935462);}
    </style>
<![endif]-->
  <style type="text/css">
.question { background-color:#FFEBC1; border:2px solid #FDBD3B; margin-bottom:12px; padding:0px 4px 8px 4px; }
td.formatted_questions { text-align: left; white-space: normal}
td.formatted_questions ol { margin-top: 0px; margin-bottom: 0px; }
  </style>
 <link href="/plugin_assets/redmine_vote/stylesheets/stylesheet.css?1241479970" media="screen" rel="stylesheet" type="text/css" />
<!-- page specific tags -->
    <link href="/stylesheets/scm.css?1238935462" media="screen" rel="stylesheet" type="text/css" /></head>
<body>
<div id="wrapper">
<div id="top-menu">
    <div id="account">
        <ul><li><a href="/login" class="login">Sign in</a></li>
<li><a href="/account/register" class="register">Register</a></li></ul>    </div>
    
    <ul><li><a href="/" class="home">Home</a></li>
<li><a href="/projects" class="projects">Projects</a></li>
<li><a href="http://www.redmine.org/guide" class="help">Help</a></li></ul></div>
      
<div id="header">
    <div id="quick-search">
        <form action="/search/index/nexuiz" method="get">
        <a href="/search/index/nexuiz" accesskey="4">Search</a>:
        <input accesskey="f" class="small" id="q" name="q" size="20" type="text" />
        </form>
        
    </div>
    
    <h1>Nexuiz</h1>
    
    <div id="main-menu">
        <ul><li><a href="/projects/show/nexuiz" class="overview">Overview</a></li>
<li><a href="/projects/activity/nexuiz" class="activity">Activity</a></li>
<li><a href="/projects/roadmap/nexuiz" class="roadmap">Roadmap</a></li>
<li><a href="/projects/nexuiz/issues" class="issues">Issues</a></li>
<li><a href="/projects/nexuiz/news" class="news">News</a></li>
<li><a href="/projects/nexuiz/documents" class="documents">Documents</a></li>
<li><a href="/wiki/nexuiz" class="wiki">Wiki</a></li>
<li><a href="/projects/list_files/nexuiz" class="files">Files</a></li>
<li><a href="/repositories/show/nexuiz" class="repository">Repository</a></li>
<li><a href="/ezfaq/index/nexuiz" class="ezfaq">FAQ</a></li></ul>
    </div>
</div>

<div class="nosidebar" id="main">
    <div id="sidebar">        
        
        
    </div>
    
    <div id="content">
				
        <h2>sprite-to-num.sh</h2>

<div class="attachments">
<p>fruitiex's script to slice them - 
   <span class="author">-z-, 06/28/2009 10:56 AM</span></p>
<p><a href="/attachments/download/273/sprite-to-num.sh">Download</a>   <span class="size">(470 Bytes)</span></p>

</div>
&nbsp;
<div class="autoscroll">
<table class="filecontent CodeRay">
<tbody>


<tr><th class="line-num" id="L1"><a href="#L1">1</a></th><td class="line-code"><pre>#!/bin/bash
</pre></td></tr>


<tr><th class="line-num" id="L2"><a href="#L2">2</a></th><td class="line-code"><pre>offset=0
</pre></td></tr>


<tr><th class="line-num" id="L3"><a href="#L3">3</a></th><td class="line-code"><pre>numsize=64
</pre></td></tr>


<tr><th class="line-num" id="L4"><a href="#L4">4</a></th><td class="line-code"><pre>i=0
</pre></td></tr>


<tr><th class="line-num" id="L5"><a href="#L5">5</a></th><td class="line-code"><pre>while [ $i -lt 13 ];do convert -crop $((numsize))x$numsize+$offset+0 numbers.png num_$i.tga;convert -crop $((numsize))x$numsize+$offset+0 numbers_outline.png num_$((i))_stroke.tga;offset=$((offset+$numsize));i=$((i+1));done
</pre></td></tr>


<tr><th class="line-num" id="L6"><a href="#L6">6</a></th><td class="line-code"><pre>mv num_10.tga num_minus.tga
</pre></td></tr>


<tr><th class="line-num" id="L7"><a href="#L7">7</a></th><td class="line-code"><pre>mv num_10_stroke.tga num_minus_stroke.tga
</pre></td></tr>


<tr><th class="line-num" id="L8"><a href="#L8">8</a></th><td class="line-code"><pre>
</pre></td></tr>


<tr><th class="line-num" id="L9"><a href="#L9">9</a></th><td class="line-code"><pre>mv num_11.tga num_plus.tga
</pre></td></tr>


<tr><th class="line-num" id="L10"><a href="#L10">10</a></th><td class="line-code"><pre>mv num_11_stroke.tga num_plus_stroke.tga
</pre></td></tr>


<tr><th class="line-num" id="L11"><a href="#L11">11</a></th><td class="line-code"><pre>
</pre></td></tr>


<tr><th class="line-num" id="L12"><a href="#L12">12</a></th><td class="line-code"><pre>mv num_12.tga num_colon.tga
</pre></td></tr>


<tr><th class="line-num" id="L13"><a href="#L13">13</a></th><td class="line-code"><pre>mv num_12_stroke.tga num_colon_stroke.tga
</pre></td></tr>


</tbody>
</table>
</div>



        
    </div>
</div>

<div id="ajax-indicator" style="display:none;"><span>Loading...</span></div>
	
<div id="footer">
    Powered by <a href="http://www.redmine.org/">Redmine</a> &copy; 2006-2009 Jean-Philippe Lang
</div>
</div>

</body>
</html>
