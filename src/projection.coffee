class Projection
    #http://wiki.openstreetmap.org/wiki/Mercator
    @ORIGIN_SHIFT: Math.PI * 6378137 # 20037508.342789244
    
    @latlon2xy: (lat, lon) ->
        lat = parseFloat(lat)
        lon = parseFloat(lon)
        #Converts given lat/lon in WGS84 Datum to XY in Spherical Mercator EPSG:900913
        mx = lon * Projection.ORIGIN_SHIFT / 180.0
        
        if lat > 89.5
            lat = 89.5
        if lat < -89.5
            lat = -89.5
        
        my = Math.log(Math.tan((90.0 + lat) * Math.PI / 360.0 )) / (Math.PI / 180.0)
        
        my = my * Projection.ORIGIN_SHIFT / 180.0

        return [mx, my]

     @xy2latlon: (mx, my) ->
        #Converts XY point from Spherical Mercator EPSG:900913 to lat/lon in WGS84 Datum

        lon = (mx / Projection.ORIGIN_SHIFT) * 180.0
        lat = (my / Projection.ORIGIN_SHIFT) * 180.0
        lat = 180.0 / Math.PI * (2 * Math.atan( Math.exp( lat * Math.PI / 180.0)) - Math.PI / 2.0)
        return [lat, lon]
