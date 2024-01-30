# Bell Observatory Automation Script
This code is an attempt to create a fully-automated observatory experience with one click.
Observers create a TargetList.txt file using the template, and then running the AutomationScript.vbs script will trigger a filename input.
Users then input the target list file name (".txt"-inclusive), and the observatory will start up, run the targets, and shut down with no further user input.
## Installation/Usage
Please see the code for comments and specific documentation
This code was built for Windows (hence .vbs) using an ACE SmartDome, PlaneWave Instruments 4 Telescope and Shutter software, and MaximDL for imaging and file saving.
## Roadmap/Bugs
I will attempt to publish bugs in the Issues page, and the roadmap is in the RoadMap file.
## Credits
The "barebones" of this code (specifically the Process, TakeExposure, and PrepareToImage subroutines, and the GetSequenceNumber function) were initially written by ACP Observatory Control Software.  See [https://diffractionlimited.com/maxim-dl-extras/] for the original code, specifically "Sequenced Image Acquisition".  I cannot find the original author yet.
