for X in *.aft; do
	aft "$X"
	aft "$X"
	aft "$X"
	{ cat header.html-part; perl -ne 'print unless 1 .. /<body>/ or /<\/body>/ .. 0' "${X%.aft}.html"; cat footer.html-part; } > "../${X%.aft}.html"
done
