# RoadMap
## Current Features/Outline of Script
* Prefix for FITS images is created (kYYMMDD).  The DD is for the "following day", or the UTC-time day, since we usually observe starting past 6pm.
* Log file is created, and this log file takes input from pretty much every step in the process (it's detailed!)
* Checks that dome is already closed/stationary; if not, makes it so!
* Before observatory starts up, script calls a Python AstroPy query to determine if the solar altitude is low enough to observe (<-8d)
  * If too high, will cycle 10 minute check loop
  * If low enough, proceeds to startup observatory
* All components of Observatory start up
  * Bug light on stepladder turns off
  * Camera connects to MaximDL, starts cooling (needs to get to -20C) (~180 seconds total)
  * Dome homes (if it isn't already) and simultaneously opens (~120 seconds total)
  * Telescope connects to PWI4 and starts homing (~30 seconds total).  Telescope commands are run via closed, internal PWI server.
  * The Camera cooling, Dome opening, and Telescope homing all run simulataneously to save time.  After 180 seconds, script checks if $|(-20 - T_{Cam})|<3$.  If yes, then proceed.  If not, then loop 10 seconds for check.
    * This is because sometimes in the summer, the ambient temp will reach +35C!
* Take bias frames
  * Script reads BiasList.txt (basically, just goes to Polaris).
  * Calls Process subroutine which reads through each line of the text file, doing different things based on what the line says (see [Process subroutine] in main code for details).
    * When Process first reads the RA/Dec combo in the text file, scope will slew to target, and then dome will follow scope azimuth after about 10 seconds.  Then, checks every 5 seconds to see if dome azimuth is within 3 degrees of scope azimuth.
    * Before every exposure, calls Python AstroPy query to determine if sun is too high (>-8d) or if moon is too close to target (<20d) or if target is too low in sky (<30d).
      * If sun too high or moon too close, runs EndOfNight subroutine and then shuts down.
      * If sun low enough _and_ moon far enough from target, proceeds
    * Also before every exposure, runs dome azimuth check to adjust to slightly-new scope azimuth (from sky rotation).
  * Takes 9 bias frames, save them into data folder as kYYMMDD####.
* Open Optical Tube Assembly (OTA) shutters
* Take light frames
  * Script reads BiasList.txt (basically, just goes to Polaris).
  * Calls Process subroutine which reads through each line of the text file, doing different things based on what the line says (see [Process subroutine] in main code for details).
    * When Process first reads the RA/Dec combo in the text file, scope will slew to target, and then dome will follow scope azimuth after about 10 seconds.  Then, checks every 5 seconds to see if dome azimuth is within 3 degrees of scope azimuth.
    * Before every exposure, calls Python AstroPy query to determine if sun is too high (>-8d) or if moon is too close to target (<20d) or if target is too low in sky (<30d).
      * If sun too high or moon too close, runs EndOfNight subroutine and then shuts down.
      * If sun low enough _and_ moon far enough from target, proceeds
    * Also before every exposure, runs dome azimuth check to adjust to slightly-new scope azimuth (from sky rotation).
* All components of observatory shut down (called via EndOfNight subroutine)
  * This runs once last line of TargetList text file is read
  * Disables camera cooler and connection
  * Disables both telescope motor axes
  * Turns on bug light
  * Closes OTA shutters
  * Closes PWI4 software and shutter software
  * Closes dome, waits 40 seconds, then parks it.
  * Closes dome software.
  * Quits script.
## Features of TargetList
* Can input RA/Dec of target in hh:mm:ss and dd:mm:ss format
* Can also input altitude and azimuth
## Upcoming Features
* Once flat field screen is installed, create code block between shutter opening block and light frames block
  * This code block will function very similar to the bias block, but it will slew to a fixed altitude and azimuth and then turn off tracking via scope commands to stay fixed on flat field screen.
* Possible implementation of Python-based target list generator (feed coordinates, filters, exposures, etc., and will output TargetListYYMMDD.txt)
* Re-run through TargetList.txt and expose targets that were initially missed due to moon and/or target altitude.
