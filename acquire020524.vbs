' Acquire.vbs
' A rudimentary image acquisition system for automated observatories
'
' NOTE: The telescope driver used is specified in an assignment statement
'		in the first few lines of the code.  This must be changed for your
'		hardware configuration; look for the variable TelescopeDriver.
'		The camera and focuser used are those selected in MaxIm DL.
'
'
' This script executes commands for slewing the telescope, taking images,
' etc., read from an input 'target list' file.  The available commands are:
'
'	DEST path_and_prefix
'		Set the destination directory (up to the last backslash) and
'		leading part of the filename for images to be saved in this run.
'		The default is the current directory, with empty prefix.
'
'	SEQ starting_number
'		Set the sequence number of the next image (incremented with each
'		image).  Executing a DEST command automatically sets the starting
'		number to one more than	the highest value that has been used with
'		that prefix that directory, so SEQ is only needed if you want to
'		overwrite existing files.
'
'	RA right_ascension
'		Set the right ascension for the next image.  It can be specified
'		as hours, hours and minutes, or hours, minutes and seconds, using
'		free-form delimiters.
'
'	DEC declination
'		Set the declination for the next image.  It can be specified
'		as degrees, degrees and minutes, or degrees, minutes and seconds,
'		using free-form delimiters.
'
'	EXP time
'		Take an exposure of the specified time (in seconds).  The result
'		image is saved in the DEST directory as prefix#####[_f].fts, where
'		prefix is the last part of the DEST string, ##### the five-digit
'		sequence number, and f is the first letter of the selected filter.
'		The underscore and filter letter do not appear if FILT is -1.
'
'	FILT filter_number
'		Set the filter number for the next exposure.  Range is -1 (filter
'		unchanged) and 0 through 12.  The default is -1.
'
'	FOCUS time
'		Perform an autofocus sequence using the specified exposure time.
'		You must have a focuser connected to use this command!
'
'	OBJ information
'		Set information to be inserted into OBJECT key of FITS header
'		on subsequent exposures.
'
' Commands are not case sensitive, and characters after those shown are
' ignored so that you can say "EXPOSE 10" instead of "EXP 10" if preferred.
' Blank lines and any characters following a pound sign (#) are ignored.


' declarations for all variables used globally
Dim fso
Dim Tel
Set Tel = Nothing
Dim Camera
Set Camera = Nothing
Dim Filter, Root, RA, Dec, HasRA, HasDec, ExpNo, Object, RAunmod, Decunmod, az, alt, azunmod, altunmod, Observer, wait
Dim moonfile,moonranow,moondecnow,moongood,totaldistance,mooncoordsfile
Dim objalt
Dim fsun, sunfile, sunaltnow
Filter = -1
Error = ""
HasRA = False
HasDec = False

'Correctly set prefix (Root):
TimeNow = FormatDateTime(Now, vbShortDate)
year1 = 0
month1 = 0
day1 = 0
year1 = Year(TimeNow) - 2000
month1 = Month(TimeNow)
day1 = Day(TimeNow) + 1
If day1 < 10 And month1 < 10 Then
	fileprefix = "k" & year1 & "0" & month1 & "0" & day1 & "-"
ElseIf day1 < 10 And month1 >= 10 Then
	fileprefix = "k" & year1 & month1 & "0" & day1 & "-"
ElseIf day1 >= 10 And month1 < 10 Then
	fileprefix = "k" & year1 & "0" & month1 & day1 & "-"
ElseIf day1 >= 10 And month1 >= 10 Then
	fileprefix = "k" & year1 & month1 & day1 & "-"
End If

' obtain name of target list
If wscript.Arguments.Count > 0 Then
	TargetList = wscript.Arguments(0)
Else
	TargetList = InputBox( "Enter name of target list file", "Acquire" )
End If

Set fso = CreateObject( "Scripting.FileSystemObject" )
If TargetList = "" Then
	wscript.echo "A target list file name is required"
	wscript.Quit
ElseIf Not fso.FileExists( TargetList ) Then
	wscript.echo "Target list file """ & TargetList & """ not found"
	wscript.Quit
End If

'Create output log
automationprefix = Replace(fileprefix,"k","")
automationprefix = Replace(automationprefix,"-","")
outFile="C:\Users\Bell\Documents\Acquire\Logs\automationlog" & automationprefix & ".txt"
Set objFile = fso.CreateTextFile(outFile,True)
objFile.Write FormatDateTime(now, 3) & " - " & "Starting up..." & vbCrLf
objFile.Write FormatDateTime(now, 3) & " - " & "File prefix for tonight is: " & fileprefix &  vbCrLf
Set Util = CreateObject( "ASCOM.Utilities.Util" )



'Do pre-requisites (open dome, etc.)
Set o = CreateObject("WinHttp.WinHttpRequest.5.1")
Set shell = CreateObject("WScript.Shell")

'Make sure dome is already closed:
Set dome = CreateObject("AceAscom.Dome")
dome.Connected = True
If dome.ShutterStatus = 1 Then
	objFile.Write FormatDateTime(now, 3) & " - " & "Dome is already closed" & vbCrLf
End If
Do While dome.ShutterStatus <> 1
	dome.CloseShutter
	objFile.Write FormatDateTime(now, 3) & " - " & "Dome was opened, now closing..." & vbCrLf
	WScript.Sleep 5000
	If dome.ShutterStatus = 1 Then
		objFile.Write FormatDateTime(now, 3) & " - " & "Dome has been closed!" & vbCrLf
		Exit Do
	End If
Loop

'Check if sun is low enough (and wait if it's not)
SunLowEnough

'Turn off bug light
shell.Run "buglightoff.bat"
objFile.Write FormatDateTime(now, 3) & " - " & "Bug light turned off" & vbCrLf

'Connect the camera the first time we need it
Set Camera = CreateObject( "MaxIm.CCDCamera" )
Camera.DisableAutoShutdown = True
Camera.LinkEnabled = True
Camera.CoolerOn = True
'Camera should now be connected and cooling started (give about 3 minutes to cool)

'Open, and find home of dome
dome.OpenShutter

'Open and connect PWI4
shell.CurrentDirectory = "C:\Program Files (x86)\PlaneWave Instruments\PlaneWave Interface 4"
shell.Run "PWI4.exe"
objFile.Write FormatDateTime(now, 3) & " - " & "PWI4 opened" & vbCrLf
shell.CurrentDirectory = "C:\Users\Bell\Documents"
Set Tel = o
o.open "GET", "http://localhost:8220/mount/connect", False
o.send
WScript.Sleep 5000
o.open "GET", "http://localhost:8220/mount/find_home", False
o.Send

'This sleep is for the cooling, dome opening, and scope homing, to be time-efficient all under one sleep routine
WScript.Sleep 180000

'Cool camera; after 180s, check every 10s to see if dT < 1 Celcius.
Do While Not ((Camera.Temperature - Camera.TemperatureSetpoint) <= 1)
	objFile.Write FormatDateTime(now, 3) & " - " & "Camera is still cooling" & vbCrLf
	WScript.Sleep 10000
	If ((Camera.Temperature - Camera.TemperatureSetpoint) <= 1) Then
		Exit Do
	End If
Loop

dome.FindHome
WScript.Sleep 10000
If dome.AtHome = True Then
	objFile.Write FormatDateTime(now, 3) & " - " & "Dome homed" & vbCrLf
End If

'If dome.ShutterStatus = 1 Then
'	objFile.Write FormatDateTime(now, 3) & " - " & "Dome shutter is opened" & vbCrLf
'ElseIf dome.ShutterStatus = 2 Then
'	objFile.Write FormatDateTime(now, 3) & " - " & "Dome shutter is still opening" & vbCrLf
'	WScript.Sleep 20000
'End If
o.open "GET", "http://localhost:8220/rotator/enable", False
o.send
objFile.Write FormatDateTime(now, 3) & " - " & "Camera is cooled" & vbCrLf
'End of pre-requisites


' Take bias frames
'Off is to offset the exposure number for the flats and then the lights (Off=9 for flats and then Off=9+flats for lights)
Off=0
shell.CurrentDirectory = "C:\Users\Bell\Documents\Acquire"
Set f = fso.OpenTextFile( "BiasList.txt", 1 )
Do While Not f.AtEndOfStream
	Line = f.ReadLine
	N = N + 1
	Process( Replace( Trim( Line ), Chr(9), " " ))
	If Error <> "" Then objFile.Write FormatDateTime(now, 3) & " - " & Error & " at line " & N & ": " & Line & vbCrLf
Loop
f.Close

objFile.Write FormatDateTime(now, 3) & " - " & "End of BiasList.txt." & vbCrLf

shell.CurrentDirectory = "C:\Program Files (x86)\PlaneWave Instruments\PlaneWave Shutter Control\Scripts"
shell.Run "open_shutter.bat"
WScript.Sleep 15000

' read through the commands in the target list and do them one by one
Off=9
shell.CurrentDirectory = "C:\Users\Bell\Documents\Acquire"
Set f = fso.OpenTextFile( TargetList, 1 )
Do While Not f.AtEndOfStream
	Line = f.ReadLine
	N = N + 1
	Process( Replace( Trim( Line ), Chr(9), " " ))
	If Error <> "" Then objFile.Write FormatDateTime(now, 3) & " - " & Error & " at line " & N & ": " & Line & vbCrLf
Loop
f.Close
objFile.Write FormatDateTime(now, 3) & " - " & "End of " & TargetList & ".  Closing the observatory." & vbCrLf
EndOfNight


'End of main code.  Below are all of the Subroutines and Functions.


' process a single command
Sub Process( Line )
	Error = ""
	Dim I, Command, Dur, F
	I = InStr( Line, "#" )						' anything after # is a comment
	If I > 0 Then Line = Left( Line, I - 1 )

	' the first word on the line is the command
	I = InStr( Line, " " )
	If I = 0 Then
		Command = UCase( Line )
		Line = ""
	Else
		Command = UCase( Left( Line, I - 1 ))
		Line = Trim( Right( Line, Len( Line ) - I ))
	End If

	If Left( Command, 2 ) = "RA" Then
		RA = Util.HMSToHours(Line)
		objFile.Write FormatDateTime(now, 3) & " - " & "Given RA from TargetList is " & CStr(RA) & vbCrLf
		RAunmod = Line
		HasRA = RA <> 0 Or InStr( Line, "0" ) > 0
		If Not HasRA Then objFile.Write FormatDateTime(now, 3) & " - " & "Missing RA.  Trying next line." & vbCrLf
	ElseIf Left( Command, 3 ) = "DEC" Then
		Dec = Util.DMSToDegrees(Line)
		objFile.Write FormatDateTime(now, 3) & " - " & "Given Dec from TargetList is " & CStr(Dec) & vbCrLf
		Decunmod = Line
		HasDec = Dec <> 0 Or InStr( Line, "0" ) > 0
		If Not HasDec Then objFile.Write FormatDateTime(now, 3) & " - " & "Missing Dec.  Trying next line." & vbCrLf
	ElseIf Left( Command, 2 ) = "AZ" Then
		Hasaz = az <> 0 Or InStr( Line, "0" ) > 0
		az = Util.DMSToDegrees(Line)
		azunmod = Line
	ElseIf Left( Command, 3 ) = "ALT" Then
		Hasalt = alt <> 0 Or InStr( Line, "0" ) > 0
		alt = Util.DMSToDegrees(Line)
		altunmod = Line
	ElseIf Left( Command, 3 ) = "EXP" Then
		ObjectAltCheck
		If objalt > 30 Then
			objFile.Write FormatDateTime(now, 3) & " - " & "Object higher than dome slit; good to observe." & vbCrLf
			WScript.Sleep 10
		Else
			objFile.Write FormatDateTime(now, 3) & " - " & "Object too low in horizon (less than 30 degrees altitude).  Moving to next object." & vbCrLf
			Exit Sub
		End If
		MoonCheck
		If moongood = True Then
			WScript.Sleep 10
		Else
			Exit Sub
		End If
		Dur = CSng( Line )
		If Dur > 0 And Dur <= 3600 Then
			ExpNo = ExpNo + 1
			TakeExposure( Dur )
			objFile.Write FormatDateTime(now, 3) & " - " & "Imaging sky for " & CStr(Dur) & " seconds." & vbCrLf
		Else
			Error = "Invalid exposure time"
			objFile.Write FormatDateTime(now, 3) & " - " & "Invalid exposure time.  Trying new line." & vbCrLf
			Exit Sub
		End If
	ElseIf Left( Command, 4 ) = "FILT" Then
		F = CInt( Line )
		objFile.Write FormatDateTime(now, 3) & " - " & "Changing filter to position " & CStr(F) & "." & vbCrLf
		If F < -1 Or F > 12 Then
			Error = "Filter number out of range"
		ElseIf F = 0 And InStr( Line, "0" ) = 0 Then
			Error = "Missing filter number"
		Else
			Filter = F
		End If
	ElseIf Left( Command, 4 ) = "DEST" Then
		Root = Line
		ExpNo = GetSequenceNumber( Root )
	ElseIf Left( Command, 5 ) = "FOCUS" Then
		Dur = CSng( Line )
		If Dur > 0 And Dur < 60 Then
			AutoFocus( Dur )
		Else
			Error = "Invalid exposure time for autofocus"
		End If
	ElseIf Left( Command, 3 ) = "SEQ" Then
		F = CInt( Line )
		If F <= 0 Then
			Error = "Sequence number out of range"
		Else
			ExpNo = F - 1
		End If
	ElseIf Left( Command, 3 ) = "OBJ" Then
		Object = Line
		If Len( Object ) > 68 Then Object = Left( Object, 68 )
		objFile.Write FormatDateTime(now, 3) & " - " & "New object read in target list: " & Object & "." & vbCrLf
	ElseIf Left( Command, 8 ) = "OBSERVER" Then
		Observer = Line
	ElseIf Left( Command, 4 ) = "WAIT" Then
		wait = Line
		objFile.Write FormatDateTime(now, 3) & " - " & "From target list, waiting for " & CStr(wait) & " seconds." & vbCrLf
		If wait < 600 Then
			WScript.Sleep 1000*CDbl(wait)
		End If
	ElseIf Command <> "" Then
		objFile.Write FormatDateTime(now, 3) & " - " & "Unrecognized command.  Going to next line." & vbCrLf
		Exit Sub
	End If
End Sub

' take a single exposure of specified duration
Sub TakeExposure( Duration )

	'Check if sunangle has gotten too high (too late into morning):
	SunTooHigh

	PrepareToImage
	If Error <> "" Then Exit Sub
	' construct filename
	Dim Filename
	Filename = CStr( ExpNo + Off )
	If ExpNo + Off < 10 Then
		Filename = Root & fileprefix & "000" & Filename
	ElseIf ExpNo + Off >= 10 And ExpNo < 100 Then
		Filename = Root & fileprefix & "00" & Filename
	ElseIf ExpNo + Off >= 100 And ExpNo < 1000 Then
		Filename = Root & fileprefix & "0" & Filename
	End If
	On Error Goto 0
	Filename = Filename & ".fit"
	objFile.Write FormatDateTime(now, 3) & " - " & "Exposing image " & Filename & vbCrLf

	'Move dome to scope
	o.open "GET", "http://localhost:8220/status", False
	o.send
	outFileaz="C:\Users\Bell\Documents\Acquire\Utilities\PWIlog.txt"
	Set objFileaz = fso.CreateTextFile(outFileaz,True)
	logtext = o.ResponseText
	objFileaz.Write logtext & vbCrLf
	Set faz = fso.OpenTextFile( outFileaz, 1 )
	Do While Not faz.AtEndOfStream
		Line = faz.ReadLine
		N = N + 1
		If Left( Line, 19) = "mount.azimuth_degs=" Then
			azi = Replace( Line, "mount.azimuth_degs=","")
			objFile.Write FormatDateTime(now, 3) & " - " & "Dome going to scope azimuth: " & azi & vbCrLf
		End If
	Loop
	faz.Close
	dome.SlewToAzimuth(azi)
	target_folder = "C\Users\Bell\Documents\Acquire\Utilities"
	If fso.FileExists( "C\Users\Bell\Documents\Acquire\Utilities\PWILog.txt") Then
			fso.DeleteFile( target_folder & "PWILog.txt" )
	End If

	' take requested exposure
	Camera.Expose Duration, 1, Filter
	Do
		wscript.Sleep 100
	Loop Until Camera.ImageReady

	' save the image
	If Object <> "" Then Camera.SetFITSKey "OBJECT", Object
	If RA <> "" Then Camera.SetFITSKey "OBJECTRA", RAunmod
	If Dec <> "" Then Camera.SetFITSKey "OBJECTDEC", Decunmod
	If azi <> "" Then Camera.SetFITSKey "OBJECTAZ", azi
	If objalt <> "" Then Camera.SetFITSKey "OBJECTALT", objalt
	If Observer <> "" Then Camera.SetFITSKey "OBSERVER", Observer
	Camera.SaveImage Filename
End Sub

' perform an autofocus sequence and wait for it to complete
Sub AutoFocus( Duration )
	PrepareToImage
	If Error <> "" Then Exit Sub

	Dim App
	Set App = CreateObject( "MaxIm.Application" )
	App.AutoFocus Duration

	Do
		wscript.Sleep 100
	Loop While App.AutofocusStatus < 0

	If App.AutofocusStatus = 0 Then Error = "Autofocus failed"
End Sub

Sub PrepareToImage
	' if RA and Dec have been set, slew there
	If HasRA And HasDec Then
		objFile.Write FormatDateTime(now, 3) & " - " & "New object slew" & vbCrLf
		Tel.open "GET", "http://localhost:8220/rotator/stop", False
		Tel.send
		Tel.open "GET", "http://localhost:8220/rotator/goto_field?degs=180", False
		Tel.send
		Tel.open "GET", "http://localhost:8220/mount/goto_ra_dec_apparent?ra_hours=" & RA & "&dec_degs=" & DEC, False
		Tel.send
		WScript.Sleep 15000
		'Move dome to scope
		o.open "GET", "http://localhost:8220/status", False
		o.send
		outFileaz="C:\Users\Bell\Documents\Acquire\Utilities\PWIlog.txt"
		Set objFileaz = fso.CreateTextFile(outFileaz,True)
		logtext = o.ResponseText
		objFileaz.Write logtext & vbCrLf
		Set faz = fso.OpenTextFile( outFileaz, 1 )
		Do While Not faz.AtEndOfStream
			Line = faz.ReadLine
			N = N + 1
			If Left( Line, 19) = "mount.azimuth_degs=" Then
				azi = Replace( Line, "mount.azimuth_degs=","")
				objFile.Write FormatDateTime(now, 3) & " - " & "Dome going to scope azimuth: " & azi & vbCrLf
			End If
		Loop
		faz.Close
		dome.SlewToAzimuth(azi)
		Do While (Abs(dome.Azimuth - azi) > 3)
			objFile.Write FormatDateTime(now, 3) & " - " & "Dome still more than 3 degrees away from scope; Dome Azimuth: " & dome.Azimuth & vbCrLf
			WScript.Sleep 5000
			If (Abs(dome.Azimuth - azi) < 3) Then
				Exit Do
			End If
		Loop
		target_folder = "C\Users\Bell\Documents\Utilities\Acquire"
		If fso.FileExists( "C\Users\Bell\Documents\Acquire\Utilities\PWILog.txt") Then
			fso.DeleteFile( target_folder & "PWILog.txt" )
		End If
'
'		wscript.echo "Slewing to " & RA & "," & Dec		'DEBUG
		objFile.Write FormatDateTime(now, 3) & " - " & "New RA (hour decimal):" & RA & vbCrLf
		objFile.Write FormatDateTime(now, 3) & " - " & "New Dec (deg decimal):" & Dec & vbCrLf
		HasRA = False
		HasDec = False

	' if Az and Alt have been set, slew there
	ElseIf Hasaz And Hasalt Then
		objFile.Write FormatDateTime(now, 3) & " - " & "Calibration object slew" & vbCrLf
		' connect telescope the first time
		Set Tel = CreateObject( TelescopeDriver )
		Tel.open "GET", "http://localhost:8220/mount/connect", False
		Tel.send
		Tel.open "GET", "http://localhost:8220/rotator/stop", False
		Tel.send
		Tel.open "GET", "http://localhost:8220/rotator/goto_field?degs=180", False
		Tel.send
		Tel.open "GET", "http://localhost:8220/mount/goto_alt_az?alt_degs=" & alt & "&az_degs=" & az, False
		Tel.send
		WScript.Sleep 10000
		'Move dome to scope
		o.open "GET", "http://localhost:8220/status", False
		o.send
		outFileaz="C:\Users\Bell\Documents\Acquire\PWIlog.txt"
		Set objFileaz = fso.CreateTextFile(outFileaz,True)
		logtext = o.ResponseText
		objFileaz.Write logtext & vbCrLf
		Set faz = fso.OpenTextFile( outFileaz, 1 )
		Do While Not faz.AtEndOfStream
			Line = faz.ReadLine
			N = N + 1
			If Left( Line, 19) = "mount.azimuth_degs=" Then
				azi = Replace( Line, "mount.azimuth_degs=","")
				objFile.Write FormatDateTime(now, 3) & " - " & "Dome going to scope azimuth: " & azi & vbCrLf
			End If
		Loop
		faz.Close
		dome.SlewToAzimuth(azi)
		Do While (Abs(dome.Azimuth - azi) > 3)
			objFile.Write FormatDateTime(now, 3) & " - " & "Dome still more than 3 degrees away from scope; Dome Azimuth: " & dome.Azimuth & vbCrLf
			WScript.Sleep 5000
			If (Abs(dome.Azimuth - azi) < 3) Then
				Exit Do
			End If
		Loop
		target_folder = "C\Users\Bell\Documents\Acquire\Utilities"
		If fso.FileExists( "C\Users\Bell\Documents\Acquire\Utilities\PWILog.txt") Then
			fso.DeleteFile( target_folder & "PWILog.txt" )
		End If
		WScript.Sleep 45000
'
'		wscript.echo "Slewing to " & Az & "," & Alt		'DEBUG
		objFile.Write FormatDateTime(now, 3) & " - " & "New Az (hour decimal):" & az & vbCrLf
		objFile.Write FormatDateTime(now, 3) & " - " & "New Alt (deg decimal):" & alt & vbCrLf
		Hasaz = False
		Hasalt = False
	End If
End Sub

' determine the highest sequence number in use with a particular
' destination directory and filename prefix
Function GetSequenceNumber( P )
	Dim Dir, Pattern, I, J, RE, Matches, Files, fl, M

	' split the supplied Root into folder (before the last slash)
	' and filename prefix (after it)
	I = InStrRev( P, "/" )
	J = InStrRev( P, "\" )
	If I < J Then I = J
	If I > 0 Then
		Dir = Left( P, I - 1 )
		Pattern = Right( P, Len(P) - I )
		If Not fso.FolderExists( Dir ) Then
			Dim Folder
			On Error Resume Next
			Set Folder = fso.CreateFolder( Dir )
			If Folder Is Nothing Then
				Error = "Directory can't be created"
				GetSequenceNumber = ExpNo
			Else
				GetSequenceNumber = 0
			End If
			On Error Goto 0
			Exit Function
		End If
	Else
		Dir = "."		' no explicit folder, so use current directory
		Pattern = P
	End If

	' create a regular expression to match files having this prefix
	Pattern = "^" & Pattern & "([0-9][0-9][0-9]).*\.fts$"
	Set RE = New RegExp
	RE.Pattern = Pattern
	RE.IgnoreCase = True

	' find the largest sequence number of any file matching this pattern
	I = 0
	Set Files = fso.GetFolder( Dir ).Files
	For Each fl In Files
		Set Matches = RE.Execute( fl.Name )
		For Each M In Matches
			J = CInt( M.SubMatches(0) )
			If J > I Then I = J
		Next
	Next

	GetSequenceNumber = I
End Function

Sub EndOfNight
'End night (close dome, shutters) (also used if sun angle gets too high during observations):
	o.open "GET", "http://localhost:8220/rotator/stop", False
	o.send
	o.open "GET", "http://192.168.1.50:5521/outlet?5=ON", False
	o.send
	Camera.CoolerOn = False
	Camera.LinkEnabled = False
	objFile.Write FormatDateTime(now, 3) & " - " & "MaximDL and Camera closed" & vbCrLf
	o.open "GET", "http://localhost:8220/mount/disable?axis=0", False
	o.send
	WScript.Sleep 1000
	o.open "GET", "http://localhost:8220/mount/disable?axis=1", False
	o.send
	WScript.Sleep 1000
	o.open "GET", "http://localhost:8220/mount/stop", False
	o.send
	o.open "GET", "http://localhost:8220/mount/disconnect", False
	o.send
	shell.CurrentDirectory = "C:\Users\Bell\Documents\Acquire\Utilities"
	shell.Run "buglighton.bat"
	shell.Run "close_shuttermod.bat"
	shell.Run "ClosePWI4.bat"
	objFile.Write FormatDateTime(now, 3) & " - " & "PWI4 and PWI4 Shutter closed" & vbCrLf
	dome.CloseShutter
	WScript.Sleep 120000
	Do While dome.ShutterStatus <> 1
			objFile.Write FormatDateTime(now, 3) & " - " & "Dome still closing...  Dome shutter status code: " & dome.ShutterStatus & vbCrLf
			WScript.Sleep 5000
	Loop
	objFile.Write FormatDateTime(now, 3) & " - " & "Dome shutter closed" & vbCrLf
	dome.Park
	WScript.Sleep 40000
	objFile.Write FormatDateTime(now, 3) & " - " & "Dome parked" & vbCrLf
	shell.Run "CloseACE.bat"
	objFile.Write FormatDateTime(now, 3) & " - " & "ACE application closed" & vbCrLf
	objFile.Write FormatDateTime(now, 3) & " - " & "Quitting WScript..." & vbCrLf
	objFile.Close
	WScript.Quit
End Sub

Sub MoonCheck
	mooncoordsfile = Empty
	moonranow = Empty
	moondecnow = Empty
	moongood = Empty
	totaldistance = Empty
	shell.Run "C:\Users\Bell\Documents\Acquire\Utilities\checkmooncoords.bat"
	WScript.Sleep 2000

	mooncoordsfile = "C:\Users\Bell\Documents\Acquire\Utilities\mooncoords.txt"

	Set fmoon = fso.OpenTextFile(mooncoordsfile)

	moonranow = fmoon.Read(8)
	fmoon.ReadLine
	moondecnow = fmoon.Read(8)
	'WScript.Echo moonranow
	'WScript.Echo moondecnow

	moonranow = CDbl(moonranow)
	moondecnow = CDbl(moondecnow)
	totaldistance = Sqr((moondecnow-Dec)*(moondecnow-Dec)+(moonranow-RA)*(moonranow-RA))

	If totaldistance > 20 Then
		moongood = True
		moongoodstr = "Moon is far enough away!"
	ElseIf totaldistance <= 20 Then
		moongood = False
		moongoodstr = "Too close to the moon!  Trying next object."
	End If
	objFile.Write FormatDateTime(now, 3) & " - " & "Moon distance to next object: " & totaldistance & vbCrLf
	objFile.Write FormatDateTime(now, 3) & " - " & moongoodstr & vbCrLf
	fmoon.Close
	fmoon.Close
	Set fmoon = Nothing
End Sub

Sub ObjectAltCheck
	objalt = Empty
	objectcoordsfile = "C:\Users\Bell\Documents\Acquire\Utilities\objectcoords.txt"
	Set fobject = fso.CreateTextFile(objectcoordsfile,True)

	fobject.Write RA & vbCrLf
	fobject.Write Dec & vbCrLf
	fobject.Close
	shell.Run "C:\Users\Bell\Documents\Acquire\Utilities\checkobjectalt.bat"
	WScript.Sleep 2000
	'Python script will read object RA and Dec (in objectcoords.txt), convert them to alt/az, and output the alt to objectalt.txt
	objectaltfile = "C:\Users\Bell\Documents\Acquire\Utilities\objectalt.txt"

	Set falt = fso.OpenTextFile(objectaltfile)
	objalt = falt.Read(8)
	objalt = CDbl(objalt)
	
	falt.Close
	objFile.Write FormatDateTime(now, 3) & " - " & "Object Alt: " & objalt & vbCrLf
	Set falt = Nothing
End Sub

Sub SunLowEnough
fsun = Empty
sunfile = Empty
sunaltnow = Empty

shell.CurrentDirectory = "C:\Users\Bell\Documents\Acquire\Utilities"
shell.Run "checksuncoords.bat"
WScript.Sleep 6000
sunfile = "C:\Users\Bell\Documents\Acquire\Utilities\suncoords.txt"
Set fsun = fso.OpenTextFile(sunfile)
sunaltnow = fsun.Read(8)
sunaltnow = CDbl(sunaltnow)
objFile.Write FormatDateTime(now, 3) & " - " & "Current sun altitude: " & sunaltnow &  vbCrLf
If sunaltnow <= -8 Then
	objFile.Write FormatDateTime(now, 3) & " - " & "Sun is low enough, good to observe!" &  vbCrLf
End If
Do While sunaltnow > -8
	objFile.Write FormatDateTime(now, 3) & " - " & "Sun is too high!  Current sun altitude is " & sunaltnow & ". " & "Waiting 10 minutes..." &  vbCrLf
	WScript.Sleep 600000
	shell.Run "checksuncoords.bat"
	sunaltnow = fsun.Read(8)
	sunaltnow = CDbl(sunaltnow)
	fsun.Close
Loop

fsun = Empty
sunfile = Empty
sunaltnow = Empty
End Sub

Sub SunTooHigh
shell.Run "C:\Users\Bell\Documents\Acquire\Utilities\checksuncoords.bat"
WScript.Sleep 3000
sunfile = "C:\Users\Bell\Documents\Acquire\Utilities\suncoords.txt"
Set fsun = fso.OpenTextFile(sunfile)
sunaltnow = fsun.Read(8)
sunaltnow = CDbl(sunaltnow)
objFile.Write FormatDateTime(now, 3) & " - " & "Current sun altitude: " & sunaltnow &  vbCrLf
If sunaltnow <= -8 Then
	objFile.Write FormatDateTime(now, 3) & " - " & "Sun is low enough, good to observe!" &  vbCrLf
ElseIf sunaltnow > -8 Then
	objFile.Write FormatDateTime(now, 3) & " - " & "Sun is too high!  Closing dome..." &  vbCrLf
	dome.CloseShutter
	WScript.Sleep 45000
	Do While dome.ShutterStatus <> 1
		objFile.Write FormatDateTime(now, 3) & " - " & "Dome still closing...  Dome shutter status code: " & dome.ShutterStatus & vbCrLf
		WScript.Sleep 5000
	Loop
	objFile.Write FormatDateTime(now, 3) & " - " & "Dome has been closed due to sun" &  vbCrLf
	EndOfNight
End If
fsun.Close
Set fsun = Nothing
sunfile = Empty
sunaltnow = Empty
End Sub