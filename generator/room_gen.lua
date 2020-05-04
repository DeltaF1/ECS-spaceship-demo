local Geometry = require "lib.tile_geometry"
local Vector = require "vector"
local TileGrid = Geometry.TileGrid

local assetPrefix = "assets/ships/"

local propAtlas = love.graphics.newImage(assetPrefix.."props.png")

local propTypes = {
  {quad = love.graphics.newQuad(0,12,31,20,propAtlas:getDimensions()), rotate=true, rooms={[4]=true,[6]=true}}, -- table
  {quad = love.graphics.newQuad(0,0,11,12,propAtlas:getDimensions()), rotate=true, rooms={[1]=true}, frequency = 100, max=2}, -- console
  {quad = love.graphics.newQuad(31,18,14,14,propAtlas:getDimensions()), rotate=false, rooms={[3]=true}, frequency=10}, -- crate
  {quad = love.graphics.newQuad(48,21,30,10,propAtlas:getDimensions()), rotate=true, rooms={[3]=true}, frequency=10}, -- crate-long
  {quad = love.graphics.newQuad(24,0,16,9,propAtlas:getDimensions()), rotate=true, rooms={[5]=true}, frequency=10}
}

local function generate(room)
  local props = {}
  local FREQUENCY = 5
  local propgeometry = TileGrid:new()
  local size = room.geometry:size()
  for propType = 1, #propTypes do
    local prop = propTypes[propType]
    if not prop.rooms or prop.rooms[room.type] then
      count = 0
      for i = 1, prop.frequency or FREQUENCY do
        if prop.max and count >= prop.max then break end
        
        local roomX = love.math.random(1, size.x)
        local roomY = love.math.random(1, size.y)
        
        local _, _, pixelWidth, pixelHeight = prop.quad:getViewport()
        
        if prop.rotate then
          rot = love.math.random(4)
        else
          rot = 1
        end

        local angle = ({0,math.rad(90),math.rad(180),math.rad(270)})[rot]
        local offset = ({Vector(0,0), Vector(pixelHeight,0), Vector(pixelWidth,pixelHeight), Vector(0,pixelWidth)})[rot]

        if rot % 2 == 0 then
          pixelWidth,pixelHeight = pixelHeight,pixelWidth
        end
        
        local gridWidth = math.ceil(pixelWidth/TILE_WIDTH)
        local gridHeight = math.ceil(pixelHeight/TILE_WIDTH)
        
        local br = false
        for checkX = roomX, roomX+gridWidth-1 do
          for checkY = roomY, roomY+gridHeight-1 do
            if not room.geometry:get(checkX, checkY) or propgeometry:get(checkX,checkY) then
              br = true
            end
            if br then break end
          end
          if br then break end
        end
        
        -- Placement is unobstructed!
        if not br then
          for setX = roomX, roomX+gridWidth-1 do
            for setY = roomY, roomY+gridHeight-1 do
              propgeometry:set(setX, setY, "p")
            end
          end
          
          local jitter = Vector(love.math.random(1,(gridWidth*TILE_WIDTH)-pixelWidth), love.math.random(1,(gridHeight*TILE_WIDTH)-pixelHeight))
          jitter = jitter - Vector(1,1)
          offset = offset + jitter
          
          pos = Vector(roomX,roomY)
          props[#props+1] = {quad=prop.quad, position = pos, angle=angle, offset=offset, jitter=jitter, type=propType}
          count = count + 1
        end
      end
    end
  end
  
  return props
end

return {generate = generate}
