local contourHit = require "contourHit"

local image = love.image.newImageData("image.png") -- путь к файлу либо imageData
local alpha -- минимальный уровень прозрачности для определения контура. поумолчанию: 0.1
local radius -- минимально допустимый радиус между вершинами. поумолчанию: (image:getWidth() + image:getHeight()) / 20
local contour = contourHit.getContour(image, alpha, radius)

local world = love.physics.newWorld(0, 300, true)
local x, y
local typeBody -- поумолчанию dynamic
local xScale, yScale -- размеры хитбокса. поумолчанию: 1
local anchorX, anchorY = 0, 0-- точка привязки хитбокса. поумолчанию: 0.5
local hitbox = contour:getHitbox(world, x, y, typeBody, xScale, yScale, anchorX, anchorY)


--[[ СПИСОК ВОЗМОЖНОСТЕЙ
hitbox.body
hitbox.shapes - сиписок
hitbox.fixtures - сиписок

hitbox:draw()
hitbox:setFriction()
hitbox:setRestitution()
hitbox:setSensor()
hitbox:fetFilterData()
]]

local image = love.graphics.newImage("image.png")


local body = love.physics.newBody(world,0,0,"static")
local shape = love.physics.newRectangleShape(180, 50)
local fixture = love.physics.newFixture(body, shape, 1)
body:setPosition(100, 350)

function love.draw()
    local x, y = hitbox.body:getPosition()
    love.graphics.draw(image, x, y, hitbox.body:getAngle())

    hitbox:draw()
    love.graphics.rectangle("line", 10, 350 - 25, 180, 50)
    love.graphics.setColor(1, 1, 1)
end

function love.update(delta)
    world:update(delta)
end