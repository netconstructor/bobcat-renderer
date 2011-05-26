        
class Viewport
    constructor: (app) ->
        @scale_index = Config.zoom()
        if not @scale_index? or @scale_index < 0 or @scale_index > 20
            @scale_index = 10
        @heading = 0
        @geo_x = 0
        @geo_y = 0
        @application = app

        @scales = []
        
        base = 1.5
        for i in [-5 .. 1]
            @scales.push(Math.pow(base, i))
        
        v = this
        update_coordinates = ->
            v.update_coordinates()

        setInterval(update_coordinates, Config.POSITION_SAVE_PERIOD)
        return
        
    update_coordinates: ->
        Config.setLatitude(@geo_y)
        Config.setLongitude(@geo_x)
        return

    move: (dx, dy) ->
        x = Math.cos(-@heading) * dx + Math.sin(-@heading) * dy
        y = Math.cos(-@heading) * dy - Math.sin(-@heading) * dx
    
        @geo_x -= x / @scale()
        @geo_y -= y / @scale()

        @check_data_coverage()
        return

    translate_click_coordinates: (x, y) ->
        #TODO: Function for coordinates processing between screen and geo
        xx = (x / @scale()) - (@renderer.canvas.width / (2 * @scale()))
        yy = -(y / @scale()) + (@renderer.canvas.height / (2 * @scale()))
        dx = Math.cos(-@heading) * xx + Math.sin(-@heading) * yy
        dy = Math.cos(-@heading) * yy - Math.sin(-@heading) * xx
        return [@geo_x + dx, @geo_y + dy]
        
    zoom: (delta) ->
        @scale_index += delta
        @scale_index = Math.max(0, @scale_index)
        @scale_index = Math.min(@scales.length - 1, @scale_index)
        window.console && console.log('Scale: ' + @scale_index + ' (' + @scale() + ')')
        window.console && console.log('Scale denominator: 1:' + (1000 / (@scale())))
        @check_data_coverage()
        Config.setZoom(@scale_index)
        return
        
    scale: ->
        s = @scales[@scale_index]
        if isNaN(s)
            s = @scales[5]
        return s * 1.0
    
    scale_denominator: ->
        return 1000 / @scales[@scale_index]
        
    rotate: (angle) ->
        @heading += angle
        #window.console && console.log('Rotate: ' + @heading)
        @check_data_coverage()
        return

    covered_indexes: ->
        return @get_covered_indexes(@get_screen_bbox())
    
    get_covered_indexes: (bbox) ->
        [s0, s1] = @get_bbox_index(bbox[0], bbox[1])
        [e0, e1] = @get_bbox_index(bbox[2], bbox[3])
        result = []
        
        x0 = Math.min(s0, e0)
        x1 = Math.max(s0, e0)
        y0 = Math.min(s1, e1)
        y1 = Math.max(s1, e1)
        for x in [x0...x1 + 1]
            for y in [y0...y1 + 1]
                result.push([x, y])
                
        return result
        
    go_to: (geo_x, geo_y, heading) ->
        @geo_x = geo_x
        @geo_y = geo_y
        @heading = -heading
        @check_data_coverage()
        @renderer.redraw()
        
    check_data_coverage: ->        
        for index in @covered_indexes()
            if not @application.is_loaded(index)
                window.console && console.log('Missing bbox: ' + index)
                @application.load_data(index)     
        return
    
    get_bbox_index: (x, y) ->
        return [
            parseInt(x / Config.CHUNK_WIDTH), 
            parseInt(y / Config.CHUNK_HEIGHT)
        ]
        
    generate_bbox: (index) ->
        return [
            [
                Config.CHUNK_WIDTH * index[0], 
                Config.CHUNK_HEIGHT * index[1]
            ], [
                Config.CHUNK_WIDTH * (index[0] + 1), 
                Config.CHUNK_HEIGHT * (index[1] + 1)
            ]]
            
    get_screen_bbox: ->
        w = (@renderer.canvas.width / 2) / @scale()
        h = (@renderer.canvas.height / 2) / @scale()
        ww = Math.abs(w * Math.cos(@heading)) + Math.abs(h * Math.sin(@heading))
        hh = Math.abs(w * Math.sin(@heading)) + Math.abs(h * Math.cos(@heading))
    
        x1 = @geo_x - ww
        x2 = @geo_x + ww
        y1 = @geo_y - hh
        y2 = @geo_y + hh
        
        return [x1, y1, x2, y2]
    
    is_index_visible: (index) ->
        for i in @covered_indexes() when index[0] == i[0] and index[1] == i[1]
            return true
        return false
