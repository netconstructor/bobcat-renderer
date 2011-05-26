
class StyleDispatcher
    defaults: (part) ->
        part['opacity'] = 1 if not part['opacity']?
        part['fill-opacity'] = 1 if not part['fill-opacity']?
        part['z-index'] = 10 if not part['z-index']?
        part['text-position'] = 'center' if not part['text-position']?
        part['linejoin'] = 'round' if not part['linejoin']?
        part['casing-linejoin'] = 'round' if not part['casing-linejoin']?
        part['text-offset'] = 0 if not part['text-offset']?
    
    generate_object: (obj) ->
        subparts = MapCSS.set_styles(obj)
        
        result = {'casing': [], 'polygons': [], 'lines': [], 'icons': [], 'labels': [], 'click': [], 'hover': []}
        
        return result if not subparts?
            
        if obj.covered
            b = obj.chunk_bbox
            obj.geojson = {'type': 'Polygon', 'coordinates': [[[b[0][0], b[0][1]], [b[1][0], b[0][1]], [b[1][0], b[1][1]], [b[0][0], b[1][1]], [b[0][0], b[0][1]]]]}

        for part in subparts
            #Propagate defaults
            @defaults(part)
             
            if part['fill-color']?
                #Only one polygon can be rendered on the same place
                result.polygons = [new Polygon(part, obj.geojson, obj.chunk_bbox)]
        
            if part['casing-color']?
                part2 = jQuery.extend(true, {}, part);
                part2['color'] = part['casing-color']
                part2['width'] = part['casing-width']
                part2['opacity'] = part['casing-opacity']
                part2['dashes'] = part['casing-dashes']
                part2['linecap'] = part['casing-linecap']
                part2['linejoin'] = part['casing-linejoin']
                l2 = new Line(part2, obj.geojson, obj.chunk_bbox)
                l2['z-index'] = 0 #Casings sholud be drawn first
                result.casing.push(l2)

            if part['color']?
                result.lines.push(new Line(part, obj.geojson, obj.chunk_bbox))
        
            if part['icon-image']?
                # TODO Multiple POIs on same position
                result.icons.push(new Icon(part, obj.geojson))
            
            if part['text']? and obj['tags'][part['text']]?
                part['font'] = '';
                part['font'] += part['font-style'] + ' '  if part['font-style']?
                part['font'] += part['font-weight'] + ' ' if part['font-weight']?
                part['font'] += part['font-size'] + ' '   if part['font-size']?
                part['font'] += part['font-family'] + ' ' if part['font-family']?

                #TODO: Expression can be here
                text = obj['tags'][part['text']]
        
                if part['text-transform'] == 'uppercase'  
                    text = text.toUpperCase()
            
                result.labels.push(new Label(part, obj.centroid, obj.geojson, text))
                
            if part['click']?
                result.click.push(new InteractiveAreaLine(part, obj.geojson, obj.chunk_bbox, part['click'], obj['type'] + "-" + obj['ref'], obj['tags'])) 

            if part['hover']?
                result.hover.push(new InteractiveAreaLine(part, obj.geojson, obj.chunk_bbox, part['hover'], obj['type'] + "-" + obj['ref'], obj['tags'])) 
        return result        
        