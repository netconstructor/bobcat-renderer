class Renderer
    @images = {}
    @labels = {}

    constructor: (viewport) ->
        @viewport = viewport
        @viewport.renderer = this        
        @cached_indexes = []
        @layers = ['casing', 'polygons', 'lines', 'icons', 'labels']
        @special_layers = []
        @interactive_layers = ['hover', 'click']
        @layer_data = {}
        
        for l in @layers
            @layer_data[l] = {}

        for l in @interactive_layers
            @layer_data[l] = {}

        @canvas = $('#canvas')[0]
        @ctx = @canvas.getContext('2d')
        @resizeCanvas()
        
        renderer = this
        $(window).resize((event) ->
            renderer.resizeCanvas()
        )
        @style_dispatcher = new StyleDispatcher()
        canvas = MapCSS.get_canvas()
        $(@canvas).css("background-color", canvas['fill-color'] or '#fff')
        
        @add_layer('outline', [])
        
        @redrawing = false
    
    resizeCanvas: ->
        $(@canvas).attr("height", $(".bobcatMap").height())
        $(@canvas).attr("width", $(".bobcatMap").width())
        @screen_bbox = [0, 0, @canvas.width, @canvas.height]

        @redraw()
        
        return
        
    redraw: ->
        return if @redrawing
        @redrawing = true
        redrawBegin = new Date().getTime()

        #Calculate shifts
        offset_x = -@viewport.geo_x + (@canvas.width / 2) / @viewport.scale()
        offset_y = -@viewport.geo_y - (@canvas.height / 2) / @viewport.scale()

        #Initialize
        @ctx.clearRect(0, 0, @canvas.width, @canvas.height)
        
        #Render
        @ctx.rotate(@viewport.heading)
 
        objects = 0
        screen_bbox = @viewport.get_screen_bbox()
        scale = @viewport.scale()
        scale_denom = @viewport.scale_denominator()
        
        indexes = @viewport.covered_indexes()
        
        for layer in @layers
            for index in indexes when @layer_data[layer][index]?
                for obj in @layer_data[layer][index] when RenderingUtils.intersects(screen_bbox, obj.bbox) 
                    obj.draw(scale, scale_denom, this, offset_x, offset_y, @ctx)
                    objects += 1
                
        for layer in @special_layers
            for obj in @layer_data[layer]
                obj.draw(scale, scale_denom, this, offset_x, offset_y, @ctx)
                objects += 1
        
        @ctx.fillStyle = '#ddd' 
        for k, v of @viewport.waiting
            k = k.split(',')
            k = [parseInt(k[0]), parseInt(k[1])]
            grey_bbox = @viewport.generate_bbox(k)
            h = (grey_bbox[0][1] - grey_bbox[1][1])
            w = (grey_bbox[1][0] - grey_bbox[0][0])
            @ctx.fillRect(grey_bbox[0][0] + offset_x, grey_bbox[0][1] + offset_y - h, w, h)

        redrawEnd = new Date().getTime()
        
        if Config.DEBUG
            $('#debug').html('' + (redrawEnd - redrawBegin) + 'ms. (' + objects + ' x ' + @viewport.covered_indexes().length + ')')
#            [x, y] = Projection.xy2latlon(@viewport.geo_x, @viewport.geo_y)
#            $('#location').html(x + " " + y)
        @redrawing = false

        return

    @in_bbox: (bbox, point) ->
        return (point[0] >= bbox[0]) and (point[0] <= bbox[2]) and (point[1] >= bbox[1]) and (point[1] <= bbox[3])
        
    z_index_comparator: (a, b) ->
        if a['z-index'] > b['z-index']
            return 1
        else if a['z-index'] < b['z-index']
            return -1
        else if a['order'] > b['order']              
            return 1
        else if a['order'] < b['order']              
            return -1
        else
            return 0
            
    select_nearby_objects: (position) ->
        screen_bbox = @viewport.get_screen_bbox()
        indexes = @viewport.covered_indexes()
        objects = []
        ids = {}
        for index in indexes when @layer_data['hover'][index]?
            for obj in @layer_data['hover'][index] when RenderingUtils.intersects(screen_bbox, obj.bbox) and obj.is_hit(position)
                ids[obj.id] = true
                
        for index in indexes when @layer_data['hover'][index]?
            for obj in @layer_data['hover'][index] when ids[obj.id]?
                objects.push(obj)
                
        return objects

    hover: (position) ->
        @layer_data['outline'] = @select_nearby_objects(position)
        @redraw()
            
    ##########################################################################
    #Primitive drawing
    ##########################################################################

    draw_linear_object: (data, offset_x, offset_y, ctx, dashes, bbox, check_edges) ->
        for part in data
            @draw_single_path(part, offset_x, offset_y, ctx, dashes, bbox, check_edges)
        return

    draw_multi_linear_object: (data, offset_x, offset_y, ctx, dashes, bbox, check_edges) ->
        for part in data
            @draw_linear_object(part, offset_x, offset_y, ctx, dashes, bbox, check_edges)
        return
    
    draw_single_path: (part, offset_x, offset_y, ctx, dashes, bbox, omit_edges) ->    
        scale = @viewport.scale()
        part = ([(p[0] + offset_x) * scale, -(p[1] + offset_y) * scale] for p in part)
        bbox = ([(p[0] + offset_x) * scale, -(p[1] + offset_y) * scale] for p in bbox)
        
        if dashes?
            dashes = (e * scale for e in dashes)
            dash = Math.max.apply(null, dashes)
            screen_bbox = [0 - dash, 0 - dash, @canvas.width + dash, @canvas.height + dash]
            RenderingUtils.draw_dashed_path(part, ctx, dashes, screen_bbox)
        else
            RenderingUtils.draw_solid_path(ctx, part, omit_edges, bbox, @screen_bbox)
        return

    draw_image: (point, url, offset_x, offset_y, ctx) ->
        scale = @viewport.scale()
        point = [(point[0] + offset_x) * scale, -(point[1] + offset_y) * scale]
        
        RenderingUtils.draw_icon(ctx, @load_image(url), point)
        return
        
    draw_center_label: (point, text, offset_x, offset_y, center_offset, vertical_offset, halo, ctx) ->
        scale = @viewport.scale()

        point = [(point[0] + offset_x) * scale, -(point[1] + offset_y) * scale]
        point = [point[0] - center_offset, point[1] + vertical_offset]

        RenderingUtils.draw_label(ctx, point, 0, halo, text)
        return

    draw_line_label: (part, text, offset_x, offset_y, length, halo, ctx) ->
        scale = @viewport.scale()
        part = ([(p[0] + offset_x) * scale, -(p[1] + offset_y) * scale] for p in part)

        RenderingUtils.draw_line_label(ctx, part, length, halo, text)

        return
        
    draw_circle: (point, offset_x, offset_y, radius, ctx) ->
        scale = @viewport.scale()
        point = [(point[0] + offset_x) * scale, -(point[1] + offset_y) * scale]
        
        RenderingUtils.draw_circle(ctx, point, radius * scale)

    draw_marker: (point, part, offset_x, offset_y, heading, bbox, ctx) ->
        scale = @viewport.scale()
        point = [(point[0] + offset_x) * scale, -(point[1] + offset_y) * scale]
        
        ctx.translate(point[0], point[1])
        ctx.rotate(heading)
        ctx.beginPath()
        RenderingUtils.draw_solid_path(ctx, part, false, bbox, @screen_bbox)
        ctx.stroke()
        ctx.fill() 
        ctx.rotate(-heading)
        ctx.translate(-point[0], -point[1])
        
    draw_baloon: (point, offset_x, offset_y, radius, ctx) ->
        scale = @viewport.scale()
        point = [(point[0] + offset_x) * scale, -(point[1] + offset_y) * scale]
        a = radius * scale

        ctx.beginPath()
        ctx.arc(point[0], point[1] - a * 3, a, 0, Math.PI, true)
        ctx.fill()
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(point[0] - a, point[1] - a * 3)
        ctx.lineTo(point[0], point[1])
        ctx.lineTo(point[0] + a, point[1] - a * 3)
        ctx.lineTo(point[0] - a, point[1] - a * 3)
        ctx.fill()
        ctx.stroke()
        
    ##########################################################################
    #Data loading
    ##########################################################################
    load_image: (url) ->
        image = Renderer.images[url]
        if not image?
            image = new Image()
            image.src = Config.SYMBOLS_BASE_URL + url
            Renderer.images[url] = image
            
        return image
        
    load_data: (index, data) -> 
        for layer in @layers
            @layer_data[layer][index] = []
    
        for layer in @interactive_layers
            @layer_data[layer][index] = []

        for obj in data
            obj.chunk_bbox = @viewport.generate_bbox(index)
            for layer, items of @style_dispatcher.generate_object(obj)
                @layer_data[layer][index] = @layer_data[layer][index].concat(items)

        for layer in @layers
            @layer_data[layer][index].sort(@z_index_comparator)
                
        @cached_indexes.push(index)
        window.console && console.log('Renderer. loaded: ' + index)        
        
        @redraw()
        return
        
    invalidate: (index) ->
        i = @cached_indexes.indexOf(index)
        if i >= 0
            @cached_indexes.splice(i, 1)
        
        for layer in @layers
            delete @layer_data[layer][index]
        window.console && console.log('Renderer. removed: ' + index)        

    ##########################################################################
    #Layer processing
    ##########################################################################
    add_layer: (name, objects) -> 
        if @special_layers.indexOf(name) < 0
            @special_layers.push(name)
        
        @layer_data[name] = objects
        window.console && console.log('Added layer ' + name)
        @redraw()
    
    remove_layer: (name) -> 
        i = @special_layers.indexOf(name)
        if i >= 0
            @special_layers.splice(i, 1)
            
        delete @layer_data[name]
        window.console && console.log('Removed layer ' + name)        
        @redraw()

class RenderingUtils
    @draw_solid_path: (ctx, part, omit_edges, bbox, screen_bbox) ->
        ctx.moveTo(part[0][0], part[0][1])
        for i in [1...part.length]
            if omit_edges and (RenderingUtils.is_edge(part[i - 1], part[i], bbox) or not RenderingUtils.intersects(screen_bbox, [part[i][0], part[i][1], part[i - 1][0], part[i - 1][1]]))
                ctx.moveTo(part[i][0], part[i][1])
            else
                ctx.lineTo(part[i][0], part[i][1])
        return
        
    @draw_dashed_path: (part, ctx, dashes, screen_bbox) ->
        dashState = {drawing: true, patternIndex: 0, offset: 0}
        strokeStyle = ctx.strokeStyle
        
        for i in [1...part.length]
            if RenderingUtils.intersects(screen_bbox, [part[i - 1][0], part[i - 1][1], part[i][0], part[i][1]])
                RenderingUtils.draw_dashed_line(ctx, strokeStyle, dashes, dashState, part[i - 1][0], part[i - 1][1], part[i][0], part[i][1], screen_bbox)
        
    @draw_dashed_line: (ctx, strokeStyle, dashPattern, dashState, x0, y0, x1, y1, screen_bbox) ->
        blankStyle = "rgba(255,255,255,1)"
        startX = x0
        startY = y0

        dX = x1 - x0
        dY = y1 - y0
        len = Math.sqrt(dX * dX + dY * dY)
        if len == 0
            return
        dX /= len
        dY /= len
        tMax = len
  
        t = -dashState.offset
        bDrawing = dashState.drawing
        patternIndex = dashState.patternIndex
        styleInited = dashState.styleInited
        
        while t < tMax
            t += dashPattern[patternIndex]
            if t < 0
                x = 5

            if t >= tMax
                dashState.offset = dashPattern[patternIndex] - (t - tMax)
                dashState.patternIndex = patternIndex
                dashState.drawing = bDrawing
                dashState.styleInited = true
                t = tMax

            if !styleInited
                if bDrawing
                    ctx.strokeStyle = strokeStyle
                else
                    ctx.strokeStyle = blankStyle
            else
                styleInited = false

            if RenderingUtils.intersects(screen_bbox, [x0 + t * dX, y0 + t * dY, startX, startY])
                ctx.beginPath()
                ctx.moveTo(startX, startY)
                
                startX = x0 + t * dX
                startY = y0 + t * dY
            
                ctx.lineTo(startX, startY)
        
                ctx.stroke()
            else 
                startX = x0 + t * dX
                startY = y0 + t * dY

            bDrawing = !bDrawing
            patternIndex = (patternIndex + 1) % dashPattern.length
            
        return
        
    @draw_circle: (ctx, point, radius) ->
    #TODO: check intersection
        ctx.arc(point[0], point[1], radius, 0, Math.PI * 2, false)
        
    @draw_icon: (ctx, image, point) ->
    #TODO: check intersection
        if not image?
            Bobcat.log_error("Couldn't load image by URL: " + url)
            return
            
        ctx.drawImage(image, point[0] - image.width / 2, point[1] - image.height / 2)

        return
        
    @draw_label: (ctx, point, angle, halo, text) ->
    #TODO: check intersection
        ctx.translate(point[0], point[1])
        ctx.rotate(angle)
        if halo
            ctx.strokeText(text, 0, 0)
        ctx.fillText(text, 0, 0)
        ctx.rotate(-angle)
        ctx.translate(-point[0], -point[1])    

    @draw_line_label: (ctx, part, length, halo, text) ->
    #TODO: check intersection
        max_l = 0
        point = [0, 0]
        angle = 0
    
        for i in [1..part.length - 1]
            dx = part[i][0] - part[i - 1][0]
            dy = part[i][1] - part[i - 1][1]
            l = (dx * dx) + (dy * dy)
            
            if l > max_l
                max_l = l
                angle = Math.atan(dy / dx)
                point = [part[i][0] - (dx / 2) - length * Math.cos(angle), part[i][1] - (dy / 2) - length * Math.sin(angle)]
                #TODO: Should allow straight line with multiple points
        
        #Label fit longest line part 
        if max_l > length * length * 4
            RenderingUtils.draw_label(ctx, point, angle, halo, text)
        
        return

    @is_edge: (previous_point, point, bbox) ->
        return  (previous_point[0] == point[0] and (point[0] == bbox[0][0] or point[0] == bbox[1][0])) or 
                (previous_point[1] == point[1] and (point[1] == bbox[0][1] or point[1] == bbox[1][1]))
        
    @intersects: (bbox_a , bbox_b) ->
        return  RenderingUtils.line_intersects(bbox_a[0], bbox_a[2], bbox_b[0], bbox_b[2]) and 
                RenderingUtils.line_intersects(bbox_a[1], bbox_a[3], bbox_b[1], bbox_b[3]) 
        
    @line_intersects: (a_begin, a_end, b_begin, b_end) ->
        #X check, A inside interval, B inside interval or both outside
        return  (a_begin > b_begin and a_begin < b_end) or 
                (a_end > b_begin and a_end < b_end) or  
                (a_begin <= b_begin and a_end >= b_end)
