(($) ->

  window.adoratio = (c, baseURL, map)->    

    (data) ->

      data.levels = parseInt(data.levels)
      data.height = parseInt(data.height)
      data.width = parseInt(data.width)

      dj = {}

      dj.tile2long = (x,z) ->
        return (x/Math.pow(2,z)*360-180)

      dj.tile2lat = (y,z) ->
        n = Math.PI-2*Math.PI*y/Math.pow(2,z) 
        return (180/Math.PI*Math.atan(0.5*(Math.exp(n)-Math.exp(-n))))

      dj.getImgDimensions = (level) ->
        divisor = Math.pow(2, (data.levels - level))
        height  = Math.round(data.height / divisor)   
        width   = Math.round(data.width / divisor)
        
        {w: width, h:height}

      dj.template = (u, el) ->
        return (tile) ->
          ts = map.tileSize()

          k = Math.pow(2, (data.levels - tile.zoom))

          currentImgSize = dj.getImgDimensions(tile.zoom)

          insertX = tile.column * ts.x * k
          insertY = tile.row * ts.y * k 
          
          W = ts.x  
          if insertX + ts.x * k > data.width
            W = ts.x - (((insertX + ts.x * k) - data.width) / k)
            W = Math.max(0,~~W)
            el.setAttribute("width", W) 

          H = ts.y  
          if insertY + ts.y * k > data.height
            H = ts.y - (((insertY + ts.y * k) - data.height) / k)
            H = Math.max(0,~~H)
            el.setAttribute("height", H)   

          url = "#{baseURL}&svc_id=info:lanl-repo/svc/getRegion&svc_val_fmt=info:ofi/fmt:kev:mtx:jpeg2000&svc.format=image/jpeg&svc.level=#{tile.zoom}&svc.region=#{insertY},#{insertX},#{H},#{W}"

          if (insertX >= 0 and insertY >= 0 and W > 0 and H > 0)
            return url   
          null   

      dj.image = () ->

        load = (tile) ->
          element = tile.element = po.svg("image")
          size = image.map().tileSize()
          element.setAttribute("preserveAspectRatio", "none")
          element.setAttribute("width", size.x)
          element.setAttribute("height", size.y)

          lon = dj.tile2long tile.column, tile.zoom
          lat = dj.tile2lat tile.row, tile.zoom

          url = dj.template(baseURL, element)

          if (typeof url == "function") 
            element.setAttribute("opacity", 0)
            tileUrl = url(tile)
            if (tileUrl != null) 
              tile.request = po.queue.image(element, tileUrl, (img) ->
                delete tile.request
                tile.ready = true
                tile.img = img
                element.removeAttribute("opacity")
                image.dispatch({type: "load", tile: tile})
              )
            else
              tile.ready = true
              image.dispatch({type: "load", tile: tile})
          else
            tile.ready = true
            if (url != null) then element.setAttributeNS(po.ns.xlink, "href", url)
            image.dispatch({type: "load", tile: tile})

        unload = (tile) ->
          if tile.request then tile.request.abort true

        image = po.layer(load, unload)

        return image

      dj.drag = () ->
        drag = {}
        map = null
        container = null
        dragging = null

        mousedown = (e) ->
          if (e.shiftKey) then return 0
          dragging = 
            x: e.clientX,
            y: e.clientY
          
          map.focusableParent().focus()
          e.preventDefault()
          document.body.style.setProperty("cursor", "move", null)        

        mousemove = (e) ->
          if (!dragging) then return 0
          dj.cc = map.center()
          map.panBy({x: e.clientX - dragging.x, y: e.clientY - dragging.y})
          dragging.x = e.clientX
          dragging.y = e.clientY
          map.dispatch({type: "drag"})

        mouseup = (e) ->
          if (!dragging) then return 0
          mousemove(e)
          dragging = null
          document.body.style.removeProperty("cursor")        

        drag.map = (x) ->
          if (!arguments.length) then return map
          if (map) 
            container.removeEventListener("mousedown", mousedown, false)
            container = null
          
          if (map = x) 
            container = map.container()
            container.addEventListener("mousedown", mousedown, false)
          
          return drag

        window.addEventListener("mousemove", mousemove, false)
        window.addEventListener("mouseup", mouseup, false)

        return drag

      getImgTiles = (levels, zoom) ->
        ts = map.tileSize()
        k = Math.pow(2, (levels - zoom))
        currentImgSize = dj.getImgDimensions(zoom)
        w = ts.x * k
        h = ts.y * k

        columns: currentImgSize.w * k / w,
        rows: currentImgSize.h * k / h

      getImgCenter = (levels, zoom) ->
        t = getImgTiles(levels, zoom)

        lon: dj.tile2long(t.columns/2, zoom),
        lat: dj.tile2lat(t.rows/2, zoom)


      getImgPosition = (levels, zoom) ->
        t = getImgTiles(levels, zoom)
        topLat = dj.tile2lat 0, zoom
        bottomLat = dj.tile2lat t.rows, zoom
        leftLon = dj.tile2long 0, zoom
        rightLon = dj.tile2long t.columns, zoom

        topLeft: map.locationPoint({lat:topLat, lon:leftLon}),
        bottomRight: map.locationPoint({lat:bottomLat, lon:rightLon})

      po = org.polymaps

      map.add(po.dblclick())
        .add(dj.drag())
        .add(po.wheel())
        # .add(po.grid()) #debug
        # .add(po.hash()) #debug      
      

      # FIRST ZOOM AND POSITION

      startZoom = data.levels + Math.log(c.clientWidth)/Math.log(2) - Math.log(data.width)/Math.log(2)

      map.zoomRange([startZoom, data.levels])
        .zoom(startZoom)

      dj.cc = map.center()

      map.center(getImgCenter(data.levels, startZoom))

      map.on 'zoom', ->
        p = getImgPosition(data.levels, map.zoom())
        map.position = p

      map.on 'drag', ->
        p = getImgPosition(data.levels, map.zoom())
        currentImgSize = dj.getImgDimensions(map.zoom())

        map.position = p

        if p.topLeft.x + currentImgSize.w > 20 and p.bottomRight.y > 20 and p.bottomRight.x - currentImgSize.w < c.clientWidth-20 and p.topLeft.y < c.clientHeight-20
          0
        else 
          map.center(dj.cc)

      map.add(dj.image())

      return map 

)(jQuery)