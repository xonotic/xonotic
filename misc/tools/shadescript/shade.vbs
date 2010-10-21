option explicit 


Const ForReading = 1
Const ForWriting = 2
Const ForAppending = 8

dim CRLF 

CRLF = Chr(13) & Chr(10)

dim scriptFullName, scriptPath 
scriptFullName = WScript.ScriptFullName
scriptPath = Left ( scriptFullName, InStrRev ( scriptFullName, WScript.ScriptName) - 1 )

dim objFSO, setfolder, re, shader, objShaderTemplate, shaderTemplate
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set setfolder = objFSO.GetFolder(scriptPath)
Set re = New RegExp

re.IgnoreCase = True
re.Global = True
re.Pattern = ""

Set shader = objFSO.OpenTextFile (scriptPath & "\" & setfolder.name & ".shader", ForWriting, True)

Set objShaderTemplate = objFSO.OpenTextFile(scriptPath & "\template.shader", ForReading)
shaderTemplate = objShaderTemplate.ReadAll()

function filetitle(sfilename)
	filetitle = Left(sfilename, len(sfilename) - 4)
end function 

dim noLightmap, isLiquid, isTransparent, bounceScale, shaderString
dim shaderHead, shaderTail, shaderQUI, shaderDiffuse, diffuseExtra
dim subfold, texfile, fn

For Each subfold in setfolder.Subfolders
	' shader.write "Folder: " & subfold.Name & CRLF
	For Each texfile In subfold.Files
		'Defaults		
		noLightmap 		= false
		isLiquid		= false
		isTransparent 	= false
		bounceScale 	= 1
		shaderString 	= shaderTemplate
		
		shaderHead 		= ""
		shaderTail		= ""
		shaderQUI		= ""
		shaderDiffuse	= ""
		diffuseExtra	= ""
		
		' First ignore any extra map or Thumbs.db
		re.Pattern = "_bump.|_gloss.|_norm.|_glow.|Thumbs.db"
		if not re.test(texfile.name) then			
			re.pattern = "decal"
			if re.test(texfile.name) then
				noLightmap = true
			end if
			
			re.pattern = "water"
			if re.test(texfile.name) then
				noLightmap = true
				isLiquid = true
				shaderHead = shaderHead & "	surfaceparm trans" & CRLF
				shaderHead = shaderHead & "	surfaceparm water" & CRLF
				shaderHead = shaderHead & "	qer_trans 20" & CRLF
				diffuseExtra = "blendfunc blend"
			end if
			
			re.pattern = "slime"
			if re.test(texfile.name) then
				noLightmap = true
				isLiquid = true
				shaderHead = shaderHead & "	surfaceparm trans" & CRLF
				shaderHead = shaderHead & "	surfaceparm slime" & CRLF
				shaderHead = shaderHead & "	qer_trans 20" & CRLF
			end if
			
			re.pattern = "lava"
			if re.test(texfile.name) then
				noLightmap = true
				isLiquid = true
				shaderHead = shaderHead & "	surfaceparm trans" & CRLF
				shaderHead = shaderHead & "	surfaceparm lava" & CRLF
				shaderHead = shaderHead & "	qer_trans 20" & CRLF
				diffuseExtra = "		blendfunc add"
			end if
			
			re.pattern = "glass"
			if re.test(texfile.name) then
				noLightmap = true
				shaderHead = shaderHead & "	surfaceparm trans" & CRLF
				diffuseExtra = "		blendfunc add"
			end if
			
			re.pattern = "metal"
			if re.test(texfile.name) then
				bounceScale = bounceScale + 0.25
				shaderHead = shaderHead & "	surfaceparm metalsteps" & CRLF
			end if
			
			re.pattern = "grate"
			if re.test(texfile.name) then
				bounceScale = bounceScale + 0.25
				shaderHead = shaderHead & "	surfaceparm trans" & CRLF
				diffuseExtra = "		blendfunc blend"
			end if
			
			re.pattern = "shiny"
			if re.test(texfile.name) then
				bounceScale = bounceScale + 0.25
			end if
			
			re.pattern = "dirt|terrain|old"
			if re.test(texfile.name) then
				bounceScale = bounceScale - 0.25
				shaderHead = shaderHead & "	surfaceparm dust" & CRLF
			end if
			
			shaderDiffuse = "textures/" & setfolder.name & "/" & subfold.name & "/" & texfile.name
			
			fn = scriptPath & "/" & subfold.name & "/" & filetitle(texfile.name) & "_gloss.tga" 
			if objFSO.FileExists(fn) Then
				bounceScale = bounceScale + 0.25
			end if
			
			fn = scriptPath & "/" & subfold.name & "/" & filetitle(texfile.name) & "_qei.tga" 
			if objFSO.FileExists(fn) Then
				shaderQUI = "textures/" & setfolder.name & "/" & subfold.name & "/" & filetitle(texfile.name) & "_qei.tga" 
			else
				shaderQUI = shaderDiffuse
			end if

			if not noLightmap then 
				shaderTail = "	{" & CRLF & "		map $lightmap" & CRLF & "		rgbGen identity" & CRLF & "		tcGen lightmap" & CRLF & "		blendfunc filter" & CRLF & "	}"
			end if
			
			if not bounceScale = 1 then 
				re.pattern = ","
				shaderHead = shaderHead & "	q3map_bounceScale " & re.Replace(bounceScale, ".") & CRLF
			end if
				
			re.Pattern = "%shader_name%"
			shaderString = re.Replace(shaderTemplate, "textures/" & setfolder.name & "/" & subfold.name & "-" & filetitle(texfile.name))

			re.Pattern = "%qei_name%"
			shaderString = re.Replace(shaderString, shaderQUI)

			re.Pattern = "%shader_head%"
			shaderString = re.Replace(shaderString, shaderHead)
			
			re.Pattern = "%diffuse_map%"
			shaderString = re.Replace(shaderString, shaderDiffuse)
			
			re.Pattern = "%diffuse_map_extra%"
			shaderString = re.Replace(shaderString, diffuseExtra)

			re.Pattern = "%shader_tail%"
			shaderString = re.Replace(shaderString, shaderTail)
			

			
			shader.write shaderString & CRLF & CRLF
		end if
	Next
Next
shader.Close



