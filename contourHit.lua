local t = {}

local function simplifyVertices(vertices, epsilon)
    if #vertices < 3 then return vertices end
    
    local function getSquareDistance(p1, p2)
        return (p1.x - p2.x)^2 + (p1.y - p2.y)^2
    end
    
    local function getSquareSegmentDistance(p, p1, p2)
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        
        if dx == 0 and dy == 0 then
            return getSquareDistance(p, p1)
        end
        
        local t = ((p.x - p1.x) * dx + (p.y - p1.y) * dy) / (dx * dx + dy * dy)
        
        if t < 0 then
            return getSquareDistance(p, p1)
        elseif t > 1 then
            return getSquareDistance(p, p2)
        else
            return getSquareDistance(p, {
                x = p1.x + t * dx,
                y = p1.y + t * dy
            })
        end
    end
    
    local function douglasPeucker(points, first, last, epsilon, result)
        local maxDist = 0
        local index = first
        
        for i = first + 1, last do
            local dist = getSquareSegmentDistance(points[i], points[first], points[last])
            if dist > maxDist then
                index = i
                maxDist = dist
            end
        end
        
        if maxDist > epsilon * epsilon then
            douglasPeucker(points, first, index, epsilon, result)
            douglasPeucker(points, index, last, epsilon, result)
        else
            if #result == 0 then
                -- table.insert(result, points[first])
            end
            table.insert(result, points[last])
        end
    end
    
    local result = {}
    douglasPeucker(vertices, 1, #vertices, epsilon, result)
    return result
end

local function isBoundaryPixel(imageData, x, y, width, height, threshold)
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local nx, ny = x + dx, y + dy
                if nx >= 0 and nx < width and ny >= 0 and ny < height then
                    local _, _, _, na = imageData:getPixel(nx, ny)
                    if na <= threshold then
                        return true
                    end
                else
                    return true
                end
            end
        end
    end
    return false
end

local function findFirstBoundaryPoint(imageData, width, height, threshold)
    for y = 0, height-1 do
        for x = 0, width-1 do
            local _, _, _, a = imageData:getPixel(x, y)
            if a > threshold then
                if isBoundaryPixel(imageData, x, y, width, height, threshold) then
                    return x, y
                end
            end
        end
    end
    return nil
end

local function traceContour(imageData, width, height, startX, startY, threshold, step)
    local vertices = {}
    local visited = {}
    local directions = {
        {dx = 1, dy = 0},
        {dx = 1, dy = 1},
        {dx = 0, dy = 1},
        {dx = -1, dy = 1},
        {dx = -1, dy = 0},
        {dx = -1, dy = -1},
        {dx = 0, dy = -1},
        {dx = 1, dy = -1}
    }
    
    local x, y = startX, startY
    local startDir = 0
    local firstPoint = true
    
    repeat
        if #vertices == 0 or 
           math.sqrt(math.pow(vertices[#vertices].x - x, 2) + math.abs(vertices[#vertices].y - y)) >= step then
            table.insert(vertices, {x = x, y = y})
        end
        
        local key = x * height + y
        visited[key] = true
        
        local found = false
        for i = 0, 7 do
            local dirIndex = (startDir + i) % 8
            local dir = directions[dirIndex + 1]
            local nx, ny = x + dir.dx, y + dir.dy
            
            if nx >= 0 and nx < width and ny >= 0 and ny < height then
                local _, _, _, a = imageData:getPixel(nx, ny)
                if a > threshold and isBoundaryPixel(imageData, nx, ny, width, height, threshold) then
                    local newKey = nx * height + ny
                    if not visited[newKey] or (nx == startX and ny == startY) then
                        x, y = nx, ny
                        startDir = (dirIndex + 5) % 8
                        found = true
                        break
                    end
                end
            end
        end
        
        if not found then break end
        
        if x == startX and y == startY then
            table.insert(vertices, {x = x, y = y})
            break
        end
        
    until false
    
    return vertices
end

local function isClockwise(vertices)
    if #vertices < 3 then return true end
    
    local area = 0
    for i = 1, #vertices do
        local j = i % #vertices + 1
        area = area + (vertices[j].x - vertices[i].x) * (vertices[j].y + vertices[i].y)
    end
    
    return area > 0
end

local function reverseVertices(vertices)
    local reversed = {}
    for i = #vertices, 1, -1 do
        table.insert(reversed, vertices[i])
    end
    return reversed
end


local function findSilhouetteVertices(imageData, threshold, step)
    local width = imageData:getWidth()
    local height = imageData:getHeight()
    
    local startX, startY = findFirstBoundaryPoint(imageData, width, height, threshold)
    if not startX then return {} end
    
    local vertices = traceContour(imageData, width, height, startX, startY, threshold, step)
    
    vertices = simplifyVertices(vertices, 1.5)
    
    if not isClockwise(vertices) then
        vertices = reverseVertices(vertices)
    end
    
    return vertices
end

local function unpackSilhouette(points)
    local flattened = {}
    for _, point in ipairs(points) do
        table.insert(flattened, point.x)
        table.insert(flattened, point.y)
    end
    return flattened
end


local function wrapperConttourHit(image, alpha, detals)
    image = type(image) == "string" and love.image.newImageData(image) or image
    alpha = alpha or 0.1
    detals = detals or (image:getWidth() + image:getHeight()) / 20

    local vertices = findSilhouetteVertices(image, alpha, detals)
    vertices = unpackSilhouette(vertices)
    local polygons = love.math.triangulate(vertices)

    local contour = {width = image:getWidth(), height = image:getHeight(), polygons = polygons}, vertices
    function contour:getHitbox(world, x, y, typeBody, xScale, yScale, anchorX, anchorY)
        xScale, yScale = xScale or 1, yScale or 1
        anchorX, anchorY = anchorX or 0.5, anchorY or 0.5
        local body = love.physics.newBody(world, x or 0, y or 0, typeBody or "dynamic")
        
        local polygons
        if (xScale == 1 and yScale == 1 and anchorX == 0 and anchorY == 0) then
            polygons = self.polygons
        else
            polygons = {}
            for _, polygon in ipairs(self.polygons) do
                local resizedPolygon = {}
                for i = 1, #polygon, 2 do
                    local x = polygon[i]
                    table.insert(resizedPolygon, (x - self.width * anchorX) * xScale)
                    local y = polygon[i+1]
                    table.insert(resizedPolygon, (y - self.height * anchorY) * yScale)
                end 
                table.insert(polygons, resizedPolygon)
            end
        end

        

        local fixtures = {}
        local shapes = {}
        print(#polygons)

        for i, vertices in ipairs(polygons) do
            local shape = love.physics.newPolygonShape(vertices)
            local fixture = love.physics.newFixture(body, shape, 1)
            table.insert(fixtures, fixture)
            table.insert(shapes, shape)
        end

        local hitbox = {
            body = body,
            fixtures = fixtures,
            shapes = shapes,
        }

        function hitbox:setFriction(...)
            for _, fixture in ipairs(self.fixtures) do
                fixture:setFriction(...)
            end
        end
        function hitbox:setRestitution(...)
            for _, fixture in ipairs(self.fixtures) do
                fixture:setRestitution(...)
            end
        end
        function hitbox:setSensor(...)
            for _, fixture in ipairs(self.fixtures) do
                fixture:setSensor(...)
            end
        end
        function hitbox:fetFilterData(...)
            for _, fixture in ipairs(self.fixtures) do
                fixture:fetFilterData(...)
            end
        end


        function hitbox:draw()
            love.graphics.setColor(0,1,0,0.25)
            love.graphics.push()
            love.graphics.translate(self.body:getPosition())
            love.graphics.rotate(self.body:getAngle())

            for i, fixture in ipairs(self.fixtures) do
                local vertices = {self.shapes[i]:getPoints()}
                love.graphics.polygon("fill", vertices)
                love.graphics.polygon("line", vertices)
            end
            love.graphics.setColor(0,1,0)

            love.graphics.pop()
        end

        return hitbox
    end

    return contour
end

return {
    getContour = wrapperConttourHit,
}