path = r"C:\Users\Bell\Documents\Acquire\objectcoords.txt"
outputpath = r"C:\Users\Bell\Documents\Acquire\objectalt.txt"
import astropy
import astropy.coordinates as coords
from astropy.coordinates import Angle
from astropy.coordinates import SkyCoord
from astropy.time import Time
import astropy.units as u
import time
import math

with open(path) as file:
    lines = [line.rstrip() for line in file]
file.close
objectra = lines[0]
objectdec = lines[1]
print(lines)
loc = coords.EarthLocation(lon=-86.6111 * u.deg, lat=36.9188 * u.deg)
altaz = coords.AltAz(location=loc, obstime=Time.now())
coord = SkyCoord(objectra, objectdec,unit='deg')
print(coord)
alt = coord.transform_to(altaz).alt
alt = Angle(alt)
alt = alt.degree
print(alt)

output = open(outputpath, "w")
output.write(str(alt))
output.close()