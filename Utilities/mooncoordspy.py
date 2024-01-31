path = "C:/Users/Bell/Documents/Acquire/mooncoords.txt"
import astropy
import astropy.coordinates as coords
from astropy.coordinates import Angle
from astropy.coordinates import SkyCoord
from astropy.time import Time
import astropy.units as u
import time
import math
#loc = coords.EarthLocation(lon=-86.6111 * u.deg, lat=36.9188 * u.deg)
#altaz = coords.AltAz(location=loc, obstime=Time.now())
#print(altaz)
print(Time.now())
moonranow = coords.get_moon(Time.now()).ra
moonranow = Angle(moonranow)
moonranow = moonranow.degree
moondecnow = coords.get_moon(Time.now()).dec
moondecnow = Angle(moondecnow)
moondecnow = moondecnow.degree
print(moonranow)
print(moondecnow)
with open(path, 'w') as f:
    f.write(str(moonranow))
    f.write("\n")
    f.write(str(moondecnow))
    f.close()