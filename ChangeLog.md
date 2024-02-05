# Change Log
## 2/5/24:
Added log outputs for:
* RA and Dec from Process Sub
  * Will exit sub if not a valid number
* If exp <0 or >3600
  * Will exit Sub if not a valid number (i.e: if mistyped "300s" instead of "300")
* When BiasList.txt and TargetList are done reading.
Hopefully the RA/Dec outputs will give us some insight into why the object alt check isn't processing for the current object, only the previous object.

Converted initial sun alt check into SunLowEnough Sub; added:
* fsun = Empty
* sunfile = Empty
* sunaltnow = Empty
Into the beginning of the sub; hopefully this will fix the wrong alt issue.

Converted b/t exposure sun alt check into SunTooHigh Sub (makes it easier to comment this out when running daytime tests).

Found commands for proper de-rotation and implemented them:
* http://localhost:8220/rotator/goto_field?degs=### (can set this to some arbitrary number it seems) (put this after the stop command)
* http://localhost:8220/rotator/stop (use this after going to new object) (also add this in the EndOfNight Sub)

Changed FITS header output lines:
* If azi <> "" Then Camera.SetFITSKey "OBJECTAZ", azi
*	If objalt <> "" Then Camera.SetFITSKey "OBJECTALT", objalt

Added shell.CurrentDirectory = "C:\Users\Bell\Documents\Acquire" before turning off bug light in observatory opening area.
