Current Automation Instructions:
1) Build your TargetList.txt using tab-delimiters
	a) Make sure each object block has at least
	an object name, RA, Dec, and one exposure.  RA and Dec
	are in decimal form (hour and deg, respectively), and exposure
	is in seconds.  Refer to the filter list for the number needed
	b) If you don't need to change filters from the previous
	object, you can write "filter -1" without quotes
	c) (The most important one) make sure you change the date on the
	"Dest" line.  You must keep the "-" after the date (kYYMMDD-)
2) Startup PWI4 and then the dome using ASCOM Dome Control, and make sure to
click "Connect" then slave dome to scope (If you don't startup PWI4 first,
they won't connect to each other)
3) Move your target list into the Acquire folder (it should be pinned on
Windows File Explorer left tab)
4) Double click acquire010224.vbs, and input your TargetList.txt name 