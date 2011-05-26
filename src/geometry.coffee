class Line
    constructor: (style, geojson, chunk_bbox) ->
        @style = style
        @geojson = geojson
        @chunk_bbox = chunk_bbox        
        @bbox = GeometryUtils.evaluate_bbox(geojson)
        this['z-index'] = @style['z-index']
    
    draw: (scale, scale_denominator, renderer, offset_x, offset_y, ctx) ->
        if (@style['min-scale']? and scale < @style['min-scale']) or (@style['max-scale']? and scale > @style['max-scale'])
            return    
    
        ctx.strokeStyle = @style['color'] if @style['color']? and ctx.strokeStyle != @style['color']
        ctx.lineWidth = @style['width'] * scale if @style['width']? and ctx.lineWidth != @style['width'] * scale
        ctx.lineCap = @style['linecap'] if @style['linecap']? and ctx.lineCap != @style['linecap']
        ctx.lineJoin = @style['linejoin'] if @style['linejoin']? and ctx.lineJoin != @style['linejoin']
        ctx.globalAlpha = @style['opacity'] if @style['opacity']? and @style['opacity'] != ctx.globalAlpha

        ctx.beginPath()
        if @geojson.type == 'LineString'
            renderer.draw_single_path(@geojson.coordinates, offset_x, offset_y, ctx, @style['dashes'], @chunk_bbox, true)
        else if @geojson.type == 'MultiLineString' or @geojson.type == 'Polygon'
            renderer.draw_linear_object(@geojson.coordinates, offset_x, offset_y, ctx, @style['dashes'], @chunk_bbox, true)
        else if @geojson.type == 'MultiPolygon'
            renderer.draw_multi_linear_object(@geojson.coordinates, offset_x, offset_y, ctx, @style['dashes'], @chunk_bbox, true)
        ctx.stroke()        
        
class Polygon
    constructor: (style, geojson, chunk_bbox) ->
        @style = style
        @geojson = geojson
        @chunk_bbox = chunk_bbox
        @bbox = GeometryUtils.evaluate_bbox(geojson)
        this['z-index'] = @style['z-index']

    draw: (scale, scale_denominator, renderer, offset_x, offset_y, ctx) ->
        if (@style['min-scale']? and scale < @style['min-scale']) or (@style['max-scale']? and scale > @style['max-scale'])
            return
    
        shift_x = 0
        shift_y = 0

        ctx.globalAlpha = @style['fill-opacity'] if @style['fill-opacity']? and @style['fill-opacity'] != ctx.globalAlpha
        if @style['fill-image']?
            image = renderer.load_image(@style['fill-image'])
            if image?
                ctx.fillStyle = ctx.createPattern(image, 'repeat')
                shift_x = -offset_x % (image.width / scale)
                shift_y = -offset_y % (image.height / scale)
                
                ctx.translate(-shift_x * scale, +shift_y * scale)
            else
                Bobcat.log_error("Couldn't load polygon texture by URL: " + @style['fill-image'])
        else
            ctx.fillStyle = @style['fill-color'] if @style['fill-color']? and ctx.fillStyle != @style['fill-color']

        ctx.beginPath()
        
        if @geojson.type == 'Polygon'
            renderer.draw_linear_object(@geojson.coordinates, offset_x + shift_x, offset_y + shift_y, ctx, null, @chunk_bbox, false)
        else if @geojson.type == 'MultiPolygon'
            renderer.draw_multi_linear_object(@geojson.coordinates, offset_x + shift_x, offset_y + shift_y, ctx, null, @chunk_bbox, false)

        ctx.closePath()
        ctx.fill()   

        if shift_x > 0 or shift_y > 0
            ctx.translate(+shift_x * scale, -shift_y * scale)

class Icon
    constructor: (style, geojson) ->
        @style = style
        @geojson = geojson
        @bbox = GeometryUtils.evaluate_bbox(geojson)

    draw: (scale, scale_denominator, renderer, offset_x, offset_y, ctx) ->
        #TODO: Bbox for icons
        if (@style['min-scale']? and scale < @style['min-scale']) or (@style['max-scale']? and scale > @style['max-scale'])
            return
        if @geojson.type == 'Point'
            renderer.draw_image(@geojson.coordinates, @style['icon-image'], offset_x, offset_y, ctx)
        else if @geojson.type == 'MultiPoint'
            for point in @geojson.coordinates
                renderer.draw_image(point, @style['icon-image'], offset_x, offset_y, ctx)
    
class Label
    constructor: (style, centroid, geojson,  text) ->
        @style = style
        @geojson = geojson
        @text = text
        @bbox = GeometryUtils.evaluate_bbox(geojson)
        
        if @style['text-position'] == 'center'
            if geojson.type == "Point"
                @centroid = geojson.coordinates
            else if centroid?
                @centroid = centroid
            else
                @centroid = GeometryUtils.evaluate_centroid(geojson)
        
    draw: (scale, scale_denominator, renderer, offset_x, offset_y, ctx) ->
        if (@style['min-scale']? and scale < @style['min-scale']) or (@style['max-scale']? and scale > @style['max-scale'])
            return
        ctx.fillStyle = @style['text-color'] if @style['text-color']? and ctx.fillStyle != @style['text-color']
        ctx.strokeStyle = @style['text-halo-color'] if @style['text-halo-color']? and ctx.strokeStyle != @style['text-halo-color']
        halo = false
        if @style['text-halo-radius']? 
            if ctx.lineWidth != @style['text-halo-radius']
                ctx.lineWidth = @style['text-halo-radius'] 
            halo = true
        ctx.textBaseline = 'middle' if ctx.textBaseline != 'middle'
        ctx.font = @style['font'] if ctx.font != @style['font']
            
        if not @style['center-offset']?
            @style['center-offset'] = ctx.measureText(@text).width / 2

        if @style['text-position'] == 'center'
            renderer.draw_center_label(@centroid, @text, offset_x, offset_y, @style['center-offset'], @style['text-offset'], halo, ctx)
        else if @style['text-position'] == 'line' and @geojson.type == 'LineString'
            renderer.draw_line_label(@geojson.coordinates, @text, offset_x, offset_y, @style['center-offset'], halo, ctx)
        else if @style['text-position'] == 'line' and @geojson.type == 'MultiLineString'
            for part in @geojson.coordinates
                renderer.draw_line_label(part, @text, offset_x, offset_y, @style['center-offset'], halo, ctx)

        #TODO: Bbox for labels
        #TODO: max-width                
        #TODO: text-decoration

class PositionMarker
    constructor: (position_callback) ->
        @position_callback = position_callback
        
    draw: (scale, scale_denominator, renderer, offset_x, offset_y, ctx) ->
        ctx.fillStyle = '#0a0'
        ctx.strokeStyle = '#090'
        ctx.lineWidth = 1
        
        pos = @position_callback()
        
        #No position -> no marker
        if not pos.coordinates?
            return
        
        ctx.beginPath()
        if isNaN(pos.speed) or pos.speed < Config.MINIMAL_SPEED or isNaN(pos.heading)
            if not pos.gps_on
                age = (new Date()).getTime() - pos.timestamp
                ctx.globalAlpha = 1 - (age / Config.POSITION_TTL)
            renderer.draw_circle(pos.coordinates, offset_x, offset_y, 20 / scale, ctx)
            ctx.stroke()
            ctx.fill() 
        else
            a = 20
            x = pos.coordinates[0]
            y = pos.coordinates[1]
            part = [[0, 0], [0 - (a / 2), 0 + (a / 2)], [0, 0 - a], [0 + (a / 2), 0 + (a / 2)], [0, 0]]
            renderer.draw_marker(pos.coordinates, part, offset_x, offset_y, pos.heading, [-a/2, -a/2, a/2, a/2], ctx)

        ctx.globalAlpha = 1 if ctx.globalAlpha != 1
                   
        if not isNaN(pos.accuracy) and pos.accuracy < Config.MAX_DISPLAY_ACCURACY and pos.accuracy > Config.MIN_DISPLAY_ACCURACY
            ctx.strokeStyle = '#ad9'
            ctx.beginPath()
            renderer.draw_circle(pos.coordinates, offset_x, offset_y, pos.accuracy * scale, ctx)
            ctx.stroke()
        return
        
class DestinationMarker
    constructor: (position) ->
        @position = position

    draw: (scale, scale_denominator, renderer, offset_x, offset_y, ctx) ->
        ctx.strokeStyle = '#900'
        ctx.fillStyle = '#a00'
        ctx.lineWidth = 1
        
        ctx.beginPath()
        renderer.draw_baloon(@position, offset_x, offset_y, 10 / scale, ctx)
        
        ctx.fill()
        ctx.stroke()        
        return

class Route
    constructor: (route_callback) ->
        @route_callback = route_callback
        
    draw: (scale, scale_denominator, renderer, offset_x, offset_y, ctx) ->
        ctx.strokeStyle = '#0d0'
        ctx.lineWidth = 4
        
        route = @route_callback()

        bbox = [Number.MIN_VALUE, Number.MIN_VALUE, Number.MAX_VALUE, Number.MAX_VALUE]
        for part in route
            GeometryUtils.update_bbox(bbox, part)

        ctx.beginPath()
        renderer.draw_single_path(route, offset_x, offset_y, ctx, null, bbox, false)
        ctx.stroke()        
        
        return
        
class InteractiveAreaLine
    constructor: (style, geojson, chunk_bbox, function_name, id, tags) ->
        @style = style
        @geojson = geojson
        @visible = new Line(style, geojson, chunk_bbox)
        @bbox = GeometryUtils.evaluate_bbox(geojson)
        @function_name = function_name
        @id = id
        @tags = tags
            
    is_hit: (position) ->
        return RenderingUtils.intersects(@bbox, [position[0], position[1], position[0], position[1]])
        
    draw: (scale, scale_denominator, renderer, offset_x, offset_y, ctx) ->
        ctx.strokeStyle = '#F00'
        ctx.lineWidth = 3

        @visible.draw(scale, scale_denominator, renderer, offset_x, offset_y, ctx)