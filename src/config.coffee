class Config
    @DEBUG = true
    @BASE_URL = ''
    @NOMINATUM_BASE_URL = 'http://open.mapquestapi.com/nominatim/v1/search?'
    @SYMBOLS_BASE_URL = Config.BASE_URL + 'symbols/'
    @API_FETCH_URL = Config.BASE_URL + 'api/fetch/'
    @LOG_URL = Config.BASE_URL + 'api/log'
    @API_NMEA_URL = Config.BASE_URL + 'api/testnmea/'    
    #TODO: More sane defaults
    @DEFAULT_POSITION = {'latitude': 7550000, 'longitude': 4140000}
    @CHUNK_WIDTH = 2000
    @CHUNK_HEIGHT = 2000
    @KB_MOVE_STEP = 50
    @KB_ROTATE_STEP = 0.1
    @READ_LAST_POSITION = true
    @SAVE_LAST_POSITION = true
    @POSITION_SAVE_PERIOD: 1000 * 30
    @ARROW = {LEFT: 37, UP: 38, RIGHT: 39, DOWN: 40 }
    @SQL_CACHE_ENABLED = true #FIXME: Use modernizr
    @SQL_CACHE_SIZE = 5 * 1024 * 1024 #5Mb
    @MAX_DISPLAY_ACCURACY = 300 #Meters
    @MIN_DISPLAY_ACCURACY = 10 #Meters
    @MINIMAL_SPEED = 7 #kph
    @POSITION_TTL = 30 * 1000 #milliseconds
    @POLYGON_TILE_WIDTH = 21 #pixels
    @POLYGON_TILE_HEIGHT = 24 #pixels
    @OUT_OF_ROUTE_DISTANCE = 100 #meters
    @ARRIVED_DISTANCE = 50 #meters
    
    @latitude: ->
        lat = parseInt(localStorage['lastLatitude'])
        if not isNaN(lat) and Config.READ_LAST_POSITION
            return lat
        else 
            return Config.DEFAULT_POSITION.latitude

    @longitude: -> 
        lon = parseInt(localStorage['lastLongitude'])
        if not isNaN(lon) and Config.READ_LAST_POSITION
            return lon
        else 
            return Config.DEFAULT_POSITION.longitude
    
    @zoom: -> 
        z = parseFloat(localStorage['lastZoom'])
        if not isNaN(z) and z > 0 and Config.READ_LAST_POSITION
            return z
        else 
            return 10
        
    @setLatitude: (lat) ->
        if Config.SAVE_LAST_POSITION
            localStorage['lastLatitude'] = lat
    
    @setLongitude: (lon) ->
        if Config.SAVE_LAST_POSITION
            localStorage['lastLongitude'] = lon

    @setZoom: (zoom) ->
        if Config.SAVE_LAST_POSITION
            localStorage['lastZoom'] = zoom        
