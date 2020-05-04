local Vector = require "vector"

local room_gen = require "generator.room_gen"
local TileGrid = require "lib.tile_geometry".TileGrid
local TileSet = require "lib.tileset"

local c = require "component".makeComponentClass
local s = require "system".makeSystemClass

local assetPrefix = "assets/ships/"

local hullTileAtlas = love.graphics.newImage(assetPrefix.."tileset_inv.png")
local wallTileAtlas = love.graphics.newImage(assetPrefix.."room_0px.png")
local gridTileset = love.graphics.newImage(assetPrefix.."room_1px.png")
local greebleAtlas = love.graphics.newImage(assetPrefix.."greebles.png")
local propAtlas = love.graphics.newImage(assetPrefix.."props.png")
 
local tilesetwidth,tilesetheight = hullTileAtlas:getDimensions()

TILE_WIDTH=16

tileset = TileSet(tilesetwidth, tilesetheight, TILE_WIDTH)
 
local door_open = love.graphics.newImage(assetPrefix.."door_open.png")
local door_closed = love.graphics.newImage(assetPrefix.."door_closed.png")

local greebleQuads = {
  love.graphics.newQuad(0,0,16,32,greebleAtlas:getDimensions()), --antenna array
  love.graphics.newQuad(16,0,16,16,greebleAtlas:getDimensions()), --light box
  -- coloured boxes
  love.graphics.newQuad(16,16,8,8,greebleAtlas:getDimensions()),
  love.graphics.newQuad(16,24,8,8,greebleAtlas:getDimensions()), 
  love.graphics.newQuad(24,16,8,8,greebleAtlas:getDimensions()), 
  love.graphics.newQuad(24,24,8,8,greebleAtlas:getDimensions()),
  -- railings
  love.graphics.newQuad(32,17,16,3,greebleAtlas:getDimensions()),
  love.graphics.newQuad(32,20,16,3,greebleAtlas:getDimensions()),
  love.graphics.newQuad(32,23,16,3,greebleAtlas:getDimensions()),
  love.graphics.newQuad(32,26,16,3,greebleAtlas:getDimensions()),
  love.graphics.newQuad(32,29,16,3,greebleAtlas:getDimensions()),
  
  love.graphics.newQuad(48,0,16,32,greebleAtlas:getDimensions()), -- antenna
}

local ShipLayerClass = c("shipLayers")

local old_init = ShipLayerClass.init

function ShipLayerClass:init()
  self.hullSpriteBatch = love.graphics.newSpriteBatch(hullTileAtlas, 100)
  self.wallSpriteBatch = love.graphics.newSpriteBatch(wallTileAtlas, 100)
  self.roomChromeSpriteBatch = love.graphics.newSpriteBatch(gridTileset, 100)
  self.greebleSpriteBatch = love.graphics.newSpriteBatch(greebleAtlas, 100)
  self.propSpriteBatch = love.graphics.newSpriteBatch(propAtlas, 100)
  
  old_init(self)
end

local ShipDrawingSystem = s{"shipLayers", "shipGeometry", "position"}

function ShipDrawingSystem:onRefreshSpriteBatches(entity)
  local random = love.math.newRandomGenerator()
  local shipLayers = entity.shipLayers
  local shipGeometry = entity.shipGeometry
  local rooms = shipGeometry.rooms
  local doorMatrix = shipGeometry.doorMatrix
  local shipTiles = shipGeometry.shipTiles
  -- Drawing to spritebatches
  ----------------------------
  shipLayers.hullSpriteBatch:clear()
  shipLayers.greebleSpriteBatch:clear()
  shipLayers.roomChromeSpriteBatch:clear()
  shipLayers.wallSpriteBatch:clear()
  shipLayers.propSpriteBatch:clear()
  
  -- Greebles
  -- TODO: Center greebles that are < TILE_WIDTH wide
  -- TODO: DRY
  -- Add an offset of 1 to generate hull sprites outside of the limits
  local size = shipTiles:size() + Vector(1,1)
  local hullWidth = 2
  for x = 1,size.x+1 do
    for y = 1,size.y+1 do
      if not shipTiles:get(x,y) then
        --empty space for greebles
        if random:random() > 0.2 then
          local quad = greebleQuads[random:random(#greebleQuads)]
          local _,_,quadWidth,quadHeight = quad:getViewport()
          if shipTiles:get(x+1,y) then
            -- Pointing left
            shipLayers.greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH-(quadHeight-TILE_WIDTH)-hullWidth, (y-1)*TILE_WIDTH+quadWidth, -math.pi/2, 1, 1, 0, 0)
          elseif shipTiles:get(x-1,y) then
            -- Pointing right
            shipLayers.greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH+quadHeight+hullWidth, (y-1)*TILE_WIDTH, math.pi/2, 1, 1, 0, 0)
          elseif shipTiles:get(x,y+1) then
            -- Pointing up
            shipLayers.greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH-(quadHeight-TILE_WIDTH)+hullWidth, 0, 1, 1, 0, 0)
          elseif shipTiles:get(x,y-1) then
            -- Pointing down
            shipLayers.greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH+quadWidth, (y-1)*TILE_WIDTH+quadHeight-hullWidth, math.pi, 1, 1, 0, 0)
          end
        end
      end
    end
  end
  
  -- Hull walls
  
  -- Make a geometry object that returns true for empty space
  invGeometry = {
    get = function(self, x,y)
      return not shipTiles:get(x,y)
    end
  }
  setmetatable(invGeometry, {__index=shipTiles})
  
  floorQuad = love.graphics.newQuad(80,122,16,16,96,128)
  
  for x = 1, size.x do
    for y = 1, size.y do
      if invGeometry:get(x,y) then 
        local quad = tileset:getQuad(invGeometry,x,y)
        if quad then
          shipLayers.hullSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH)   
        end
      else
        -- Generate the blank floor tiles
        local quad = floorQuad
        shipLayers.hullSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH)
      end
    end
  end

  -- Rooms
  -- generate the "chrome" (room type highlights) and "walls" (the gray walls showing room boundaries
  for i = 1,#rooms do
    local room = rooms[i]
    
    -- A geoemtry object that treats doorways as an extra tile set to true
    local doorGeometry = {
      get = function(self, x, y)
        local pos = Vector.isvector(x) and x or Vector(x,y)
        for j = 1, #rooms do
          door = doorMatrix[i][j]
          if door then
            local vec1 = door.vec1 - room.pos + Vector(1,1)
            if door.vec1.x == door.vec2.x then
              if (pos == vec1 - Vector(1,0)) or (pos == vec1) then return "d" end
            else
              if (pos == vec1 - Vector(0,1)) or (pos == vec1) then return "d" end
            end
          end
        end
        return room.geometry:get(pos)
      end
    }
    
    local makeDoorGeometry = function(oldTilePos)
      local doorGeometry = {
        get = function(self, x, y)
          local newTilePos = Vector.isvector(x) and x or Vector(x,y)
          local otherRoomIndex = shipTiles:get(newTilePos + room.pos)
          
          assert(oldTilePos ~= newTilePos)
          
          
          for j = 1, #rooms do
            local door = doorMatrix[i][j]
            
            if door then
              local doorPos = door.vec1:min(door.vec2) - room.pos + Vector(1,1)
              local doorDir
              local doorChirality
              if door.vec1.x == door.vec2.x then
                -- Vertical door
                doorDir = 1
              else
                -- Horizontal door
                doorDir = 2
              end
              
              if oldTilePos == doorPos then
                -- Stoop is on the left/top
                doorChirality = -1
              elseif (doorDir == 1 and oldTilePos == doorPos - Vector(1,0)) or (doorDir == 2 and oldTilePos == doorPos - Vector(0,1)) then
                -- Stoop is on the right/bottom
                doorChirality = 1
              else
                doorChirality = 0
              end
              
              if doorChirality ~= 0 then
                local stoopPos
                if doorDir == 1 then
                  stoopPos = Vector(1,0)
                else
                  stoopPos = Vector(0,1)
                end
                stoopPos = stoopPos * doorChirality
                stoopPos = stoopPos + oldTilePos
                if newTilePos == stoopPos then
                  return "d"
                elseif (doorDir == 1 and (newTilePos == stoopPos + Vector(0,1) or newTilePos == stoopPos + Vector(0,-1))) or
                       (doorDir == 2 and (newTilePos == stoopPos + Vector(1,0) or newTilePos == stoopPos + Vector(-1,0))) then
                  return false
                else
                  print(newTilePos)
                end
              end
            end
          end
          
          return room.geometry:get(newTilePos)
        end
      }
    
      return setmetatable(doorGeometry, {__index=room.geometry})
    end
    
    if room then
      shipLayers.roomChromeSpriteBatch:setColor(room.colour[1], room.colour[2], room.colour[3], 0.5)
      shipLayers.wallSpriteBatch:setColor(0.3, 0.3, 0.3)
      local size = room.geometry:size()
      for x = 1, size.x do
        for y = 1, size.y do
          if room.geometry:get(x,y) then 
            local quad = tileset:getQuad(makeDoorGeometry(Vector(x,y)),x,y)
            if quad then
              shipLayers.roomChromeSpriteBatch:add(quad, (room.pos.x+x-1)*TILE_WIDTH, (room.pos.y+y-1)*TILE_WIDTH)
              shipLayers.wallSpriteBatch:add(quad, (room.pos.x+x-1)*TILE_WIDTH, (room.pos.y+y-1)*TILE_WIDTH)
            end
          end
        end
      end
    end
  end
  
  -- Props
  for i = 1, #rooms do
    local room = rooms[i]
    
    local size = room.geometry:size()
    
    -- Generate a room layout in some fashion
    props = room_gen.generate(room)
    
    -- Place each prop on the prop spritebatch layer
    for i = 1, #props do
      local prop = props[i]
      local position = prop.position
      position = position + room.pos - Vector(1,1)
      
      position = position * TILE_WIDTH
      
      position = position + prop.offset
      
      shipLayers.propSpriteBatch:add(prop.quad, position.x, position.y, prop.angle, 1, 1)
    end
  end
end

function ShipDrawingSystem:onDraw(entity)
  local pos = entity.position.pos
  local shipLayers = entity.shipLayers
  local shipGeometry = entity.shipGeometry
  
  local rooms = shipGeometry.rooms
  local doorMatrix = shipGeometry.doorMatrix
  
  love.graphics.push()
  love.graphics.translate(pos.x, pos.y)
  love.graphics.setColor(1,1,1)
  
  love.graphics.draw(shipLayers.greebleSpriteBatch)
  
  love.graphics.draw(shipLayers.hullSpriteBatch)
  love.graphics.draw(shipLayers.roomChromeSpriteBatch)
  love.graphics.draw(shipLayers.wallSpriteBatch)
  love.graphics.draw(shipLayers.propSpriteBatch)
  
  love.graphics.setColor(1,1,1)
  for i = 1, #rooms do
    for j = i, #rooms do
      local door = doorMatrix[i][j]
      if door then
        local vec1, vec2 = door.vec1, door.vec2
        local upperLeft = vec1:min(vec2)
        local bottomRight = vec1:max(vec2)
        local drawPos = upperLeft*TILE_WIDTH
        if vec1.x == vec2.x then
          r = math.pi/2
          drawPos = drawPos + Vector(1,0)
        else
          r = 0
          drawPos = drawPos + Vector(0,-1)
        end

        love.graphics.draw(door.open and door_open or door_closed, drawPos.x, drawPos.y, r)
      end
    end
  end
  love.graphics.pop()
end

function DEBUGDrawing(self)
  if DEBUG.rect_bounds then
    love.graphics.setColor(1,0,0)
    for i = 1,#self.rects do
      local rect = self.rects[i]
      love.graphics.rectangle("line", rect[1].x*TILE_WIDTH, rect[1].y*TILE_WIDTH, rect[2].x*TILE_WIDTH, rect[2].y*TILE_WIDTH)
    end
  end
  
  if DEBUG.room_bounds then
    for i = 1,#self.rooms do
      local room = self.rooms[i]
      love.graphics.setColor(room.colour)
      love.graphics.rectangle("line", room.pos.x*TILE_WIDTH, room.pos.y*TILE_WIDTH, (room.geometry:size()*TILE_WIDTH):unpack())
    end
  end
  
  if DEBUG.generator_metadata then
    love.graphics.setColor(1,0,0)
    for i = 1, #self.rooms do
      local room = self.rooms[i]
      local meta = room.generator_metadata or {}
      love.graphics.setColor(1,0,0)
      love.graphics.print(meta.bestArea or "N/A", room.pos.x*TILE_WIDTH, room.pos.y*TILE_WIDTH)
    end
  end
end


return {ShipDrawingSystem=ShipDrawingSystem, ShipLayerClass=ShipLayerClass}