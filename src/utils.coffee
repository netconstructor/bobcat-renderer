class GeometryUtils
    @distance_point_to_line: (point, line) ->
        px = line[1][0] - line[0][0]
        py = line[1][1] - line[0][1]

        something = px*px + py*py

        u =  ((point[0] - line[0][0]) * px + (point[1] - line[0][1]) * py) / something

        if u > 1
            u = 1
        else if u < 0
            u = 0

        x = line[0][0] + u * px
        y = line[0][1] + u * py

        dx = x - point[0]
        dy = y - point[1]

        Math.sqrt(dx*dx + dy*dy)

    @distance_point_to_point: (point_a, point_b) ->
        dx = point_a[0] - point_b[0]
        dy = point_a[1] - point_b[1]
        return Math.sqrt(dx*dx + dy*dy)

    @update_bbox: (bbox, part) ->
        if bbox[0] > part[0]
            bbox[0] = part[0]
        if bbox[1] > part[1]
            bbox[1] = part[1]
        if bbox[2] < part[0]
            bbox[2] = part[0]
        if bbox[3] < part[1]
            bbox[3] = part[1]
    
    @evaluate_bbox: (geojson) ->
        bbox = [Number.MAX_VALUE, Number.MAX_VALUE, Number.MIN_VALUE, Number.MIN_VALUE]
        if geojson.type == 'Point'
            bbox = [geojson.coordinates[0], geojson.coordinates[1], geojson.coordinates[0], geojson.coordinates[1]]
        else if geojson.type == 'MultiPoint' or geojson.type == 'LineString'
            for part in geojson.coordinates
                GeometryUtils.update_bbox(bbox, part)
        else if geojson.type == 'MultiLineString' or geojson.type == 'Polygon'
            for p1 in geojson.coordinates
                for part in p1
                    GeometryUtils.update_bbox(bbox, part)
        else if geojson.type == 'MultiPolygon'
            for p1 in geojson.coordinates
                for p2 in p1
                    for part in p2
                        GeometryUtils.update_bbox(bbox, part)
        else
            Bobcat.log_error("Unexpected GEOJSON type: " + geojson)

        return bbox

    @evaluate_centroid: (geojson) ->
        bbox = GeometryUtils.evaluate_bbox(geojson)
        return [(bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2]