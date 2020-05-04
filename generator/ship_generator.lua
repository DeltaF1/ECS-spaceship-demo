local Geometry = require "lib.tile_geometry".GeometryView
local TileGrid = require "lib.tile_geometry".TileGrid

local roomTypes = {
  -- Special rooms that aren't chosen by the room generator
  {name = "Helm",               wrange={2,2}, hrange={2,2}, colour = {0.8,0.9,0.1,0.85}},
  {name = "Engine",             wrange={2,2}, hrange={2,3}, colour={0.58330589736158589, 0.024793900080875231, 0.83640388831262813}},
  {name = "Airlock",         wrange={2,3}, hrange={2,3}, colour = {1,0.023,0.035}},
  -----------------------------  ROOM_PRESELECTED_OFFSET
  {name = "Storage Bay",        wrange={3,9}, hrange={3,9}, colour={0.82675021090650347, 0.1807523156814923, 0.25548658234132504}},
  {name = "Mess Hall",          wrange = {2,3}, hrange={2,3}, colour = {0.3540978676870179, 0.47236376329459961, 0.67900487187065317}},
  {name = "Sleeping quarters",  wrange = {1,2}, hrange={2,5}, colour = {0.57514179487402095, 0.79693061238668306, 0.45174307459403407}},
  {name = "Lounge",             wrange = {2,6}, hrange={2,6}, colour = {0.049609465521796903, 0.82957781845624967, 0.62650828993078767}},
  {name = "Corridor",         wrange={2,7}, hrange={1,2}, colour = {0.3,0.3,0.3}},
  {name = "Corridor",         wrange={1,2}, hrange={2,7}, colour = {0.3,0.3,0.3}},
  
}

local maxw,maxh = 0,0
for i = 1,#roomTypes do
  maxw = math.max(maxw, roomTypes[i].wrange[2])
  maxh = math.max(maxh, roomTypes[i].hrange[2])
end

local MAX_ROOM_SIZE = Vector(maxw,maxh)

-- Returns 2 vectors for the start and end of the adjacency
local function adjacency(obj1, obj2)
  if obj1.pos.x > obj2.pos.x then obj1,obj2 = obj2,obj1 end

  if obj2.pos.x == obj1.pos.x + obj1.size.x then
    local y1,y2
    y1 = math.max(obj1.pos.y, obj2.pos.y)
    y2 = math.min(obj1.pos.y + obj1.size.y, obj2.pos.y + obj2.size.y)
    
    if y2 - y1 > 0 then
      return Vector(obj2.pos.x, y1), Vector(obj2.pos.x, y2)
    end
  end

  if obj1.pos.y > obj2.pos.y then obj1,obj2 = obj2,obj1 end
  if obj2.pos.y == obj1.pos.y + obj1.size.y then
    local x1,x2
    x1 = math.max(obj1.pos.x, obj2.pos.x)
    x2 = math.min(obj1.pos.x + obj1.size.x, obj2.pos.x + obj2.size.x)
    
    if x2 - x1 > 0 then
      return Vector(x1, obj2.pos.y), Vector(x2, obj2.pos.y)
    end
  end
  
  return nil, nil
end

-- Merge two sparse arrays of the specified length
local function sparse_merge(arr1, arr2, length)
  local arr = {}
  for i = 1,length do
    arr[i] = arr1[i] or arr2[i]
  end
  return arr
end

-- Debug method
local function print_adj()
  local header = "   "
  for i = 1, #doorMatrix do
    header = header..("%2d"):format(i).." "
  end
  print(header)
  for j = 1, #rooms do
    -- row label
    local s = ("%3d"):format(j).." "
    for i = 1, #doorMatrix do
      local c = doorMatrix[i][j] and "D" or "_"
      s = s .. c .. "  "
    end
    print(s)
  end
end

local function new_room(type, random)
  local template = roomTypes[type]
  local room = {type=type}
  
  local size = Vector(random:random(unpack(template.wrange)), random:random(unpack(template.hrange)))
  if random:random() > 0.5 then
    size.x, size.y = size.y, size.x
  end
  room.size = size
  room.colour = template.colour
  room.name = template.name
  local geometry = {}
  for i = 1, size.x do
    geometry[i] = {}
    for j = 1, size.y do
      geometry[i][j] = type
    end
  end
  room.geometry = Geometry:new(geometry)
  return room
end

local function roomAdjacency(rooms, random)
  -- 2D array storing the adjacency matrix for each room in the ship
  -- nil = no adjacency, a door object = linked by said door object
  local doorMatrix = {}
  
  -- The list of room id's to merge together
  local to_merge = {}
  
  for i = 1,#rooms do
    if not doorMatrix[i] then
      doorMatrix[i] = {}
    end
    for j = i+1,#rooms do
      -- Don't check already checked rooms
      if not doorMatrix[j] or not doorMatrix[j][i] then
        local vec1, vec2 = adjacency(rooms[i], rooms[j])
        if vec1 then
          -- If two rooms are touching and are the same room type then merge them
          if rooms[i].name == rooms[j].name then
            if random:random(1,2) == 1 then
              to_merge[#to_merge+1]={i,j}
            else
              to_merge[#to_merge+1]={j,i}
            end
          else
            local door = {}
            -- Generate a random 1-wide line across the intersection surface
            if vec1.x == vec2.x then
              door.vec1 = Vector(vec1.x, random:random(vec1.y, vec2.y-1))
              door.vec2 = door.vec1 + Vector(0,1)
            elseif vec1.y == vec2.y then
              door.vec1 = Vector(random:random(vec1.x, vec2.x-1), vec1.y)
              door.vec2 = door.vec1 + Vector(1,0)
            end

            local upperLeft = door.vec1:min(door.vec2)
            local bottomRight = door.vec1:max(door.vec2)

            door.vec1 = upperLeft
            door.vec2 = bottomRight

            doorMatrix[i][j] = door
          end
        end
      end
    end
  end
  
  return doorMatrix, to_merge
end

local function mergeRooms(rooms, to_merge, doorMatrix)
  for _, merge_pair in ipairs(to_merge) do
    local i, j = unpack(merge_pair)
    if i ~= j then
      if i > j then i,j = j,i end
      
      local room1, room2 = rooms[i], rooms[j]
      
      assert(room1 and room2, "No nil merges")
      
      -- Merge the tile geometry of the two rooms together.
      -- If merging the rooms would change the upper-left corner,
      -- then update room1's position so that relative positions are preserved
      local origin_shift = room1.geometry:add(room2.geometry, room2.pos - room1.pos)
      room1.pos = room1.pos + origin_shift
      
      -- Update the room ids in the set of merge pairs since the array has shifted
      for _, pair in ipairs(to_merge) do
        if pair[1] > j then
          pair[1] = pair[1] - 1 
        elseif pair[1] == j then
          pair[1] = i
        end
        
        if pair[2] > j then
          pair[2] = pair[2] - 1
        elseif pair[2] == j then
          pair[2] = i
        end
      end
      
      -- Merge the door set into room 1
      doorMatrix[i] = sparse_merge(doorMatrix[i], doorMatrix[j], #rooms)
      
      for room=1,#rooms do
        -- Merge the door set into room 1
        doorMatrix[room][i] = doorMatrix[room][i] or doorMatrix[room][j]
        
        -- Delete the old row
        for idx = j,#rooms do
          doorMatrix[room][idx]=doorMatrix[room][idx+1]
        end
      end
      
      -- Delete the old column
      table.remove(doorMatrix, j)
      
      -- Delete the old room
      table.remove(rooms, j)
    end
  end
  
  -- Mirror the whole matrix along the diagonal
  for i = 1,#doorMatrix do
    for j = i,#doorMatrix do
      doorMatrix[i][j] = doorMatrix[j][i] or doorMatrix[i][j]
      doorMatrix[j][i] = doorMatrix[j][i] or doorMatrix[i][j]
    end
  end
end

local function overlap(start1,end1,start2,end2)
  return math.max(0, math.min(end1, end2) - math.max(start1, start2))
end

local function minDiff(arr1, arr2, dir, offset)
  local mindiff
  local offset = offset or 0
  local offdir = dir == "x" and "y" or "x"
  local overlaps = {}
  for i = 1,#arr1 do
    local current = arr1[i]
    local currentPos = current.pos:clone()
    currentPos[offdir] = currentPos[offdir] + offset
    for j =1,#arr2 do
      local opposite = arr2[j]
      local oppositePos = opposite.pos:clone()
      oppositePos[offdir] = oppositePos[offdir] + offset
      local over = overlap(oppositePos[offdir], oppositePos[offdir]+opposite.size[offdir],
                 currentPos[offdir], currentPos[offdir]+current.size[offdir])
      local diff
      if over > 0 then
        diff = oppositePos[dir] - currentPos[dir] - current.size[dir]        
      else
        diff = 100
      end

      overlaps[diff] = (overlaps[diff] or 0) + over
      if not mindiff then
        mindiff = diff
      else
        mindiff = math.min(mindiff, diff)
      end
    end
  end
  return mindiff, overlaps
end

local function merge(arr1, arr2, dir)
  dir = dir or "x"
  local offdir = dir == "x" and "y" or "x"
  
  local bestOffset = 0
  local bestOverlap = 0
  local bestDiff = 0
  for offset = 0, 0 do
    local mindiff, overlaps = minDiff(arr1, arr2, dir, offset)
    
    if overlaps[mindiff] or 0 > bestOverlap then
      bestOffset = offset
      bestOverlap = overlaps[mindiff]
      bestDiff = mindiff
    end
  end
  
  for i = 1, #arr2 do
    arr2[i].pos[dir] = arr2[i].pos[dir] - bestDiff
    arr2[i].pos[offdir] = arr2[i].pos[offdir] + bestOffset
  end
end

--local function compress(arr, dir)
--  for i=1,#arr-1 do
--    merge({arr[i]}, {arr[i+1]}, dir)
--  end
--end

local function compress(arr, dir)
  dir = dir or "x"
  -- Start from the middle of the rects to avoid bias to one side or the other
  local middle = math.floor(#arr/2)
  for i = middle,1,-1 do
    local current = arr[i]
    local neighbour = arr[i+1]
    
    current.pos[dir] = neighbour.pos[dir] - current.size[dir]
  end
  for i = middle+1,#arr do
    local current = arr[i]
    local neighbour = arr[i-1]
    if not neighbour then break end
    current.pos[dir] = neighbour.pos[dir] + neighbour.size[dir]
  end
end

-- https://stackoverflow.com/a/1501725
local function line_segment_min(a, b, point)
  local l2 = a:dist2(b)
  if l2 == 0 then
    return a:dist(point)
  end
  
  local t = math.max(0, math.min(1, (point-a) * (b-a) / l2))
  local projection = a + t * (b - a)
  return point:dist(projection)
end

local function index2xy(index, width)
  local x = (index-1) % width + 1
  local y = math.floor((index-1)/width) + 1

  return x,y
end

local function xy2index(x, y, width)
  if x < 1 or y < 1 or x > width then return -1 end
  return x + width*(y-1)
end


local function genRoomsByCrunching(random)
  -- THE GRID
  --
  -- A DIGITAL FRONTIER
  local grid = {}
  local width,height = random:random(2,3), random:random(1,2)
  
  local rooms = {}
  
 
  -- Fill the remaining space with other room types
  for i = 1,width*height do
    if not rooms[i] then
      rooms[i] = new_room(random:random(1,#roomTypes), random)
    end
  end
  
  -- Fill the grid
  -- TODO: A better way of spatial partitioning here?
  for y = 1,height do
    grid[y] = {}
    for x = 1,width do
      grid[y][x] = rooms[xy2index(x,y,width)]
    end
  end
  
  -- Generate positions within each grid tile
  -- midx,midy are used to ensure alignment so that grids can collide
  local midx = math.floor(MAX_ROOM_SIZE.x / 2)
  local midy = math.floor(MAX_ROOM_SIZE.y / 2)
  for y = 1,#grid do
    for x = 1, #grid[1] do
      local room = grid[y][x]
      -- This doesn't actually matter because they're getting crammed together anyway...
      local xoff = random:random(math.max(0, midy-room.size.x), math.min(midx - 1, MAX_ROOM_SIZE.x-room.size.x))
      local yoff = random:random(math.max(0, midy-room.size.y), math.min(midy - 1, MAX_ROOM_SIZE.y-room.size.y))
      room.pos = Vector(x*MAX_ROOM_SIZE.x + xoff, y*MAX_ROOM_SIZE.y + yoff)
      
      room.colour = room.colour or {random:random(), random:random(), random:random()}
    end
  end
  
  -- Slam the rects together

  for y = 1,#grid do
    compress(grid[y], "x")
  end

  for y = 1,#grid-1 do 
    merge(grid[y],grid[y+1],"y")
  end
  
  return rooms
end

local function genRoomsByTetris(random)
  local initialWidth, numRooms = random:random(1,20), random:random(10,20)
  
  local row = {}
  
  local rooms = {}
  
  -- midx,midy are used to ensure alignment so that grids can collide
  local midx = math.floor(MAX_ROOM_SIZE.x / 2)
  local midy = math.floor(MAX_ROOM_SIZE.y / 2)
  
  local collisionView = Geometry:new()
  
  -- Generate a row of rooms to start with
  local xOffset = 1
  local lowestY = 1
  for i = 1, initialWidth do
    local room = new_room(random:random(1, #roomTypes), random)
    
    
    local randY = random:random(math.max(1, midy-room.size.y), math.min(midy - 1, MAX_ROOM_SIZE.y-room.size.y))
    lowestY = math.max(lowestY, randY)
    room.pos = Vector(xOffset, randY)
    
    --Offset the rooms
    xOffset = xOffset + room.size.x
    
    row[i] = room
    rooms[i] = room
    
    collisionView:add(room.geometry, room.pos)
  end
  
  local function calcSurfaceArea(x,y,width, height)
    local sum = 0
    for checkY = y-1, y+height do
      for checkX = x+width, x-1, -1 do
        if (checkX < x) or (checkX >= x+width) or (checkY < y) or (checkY >= y+height) then
          if collisionView:get(checkX, checkY) then
            sum = sum + 1
          end
        else 
          if collisionView:get(checkX, checkY) then
            --collision!
            return -1, checkX, checkY
          end
        end
      end
    end
    
    return sum
  end
  
  for i = 1, numRooms do
    local room = new_room(random:random(1, #roomTypes), random)
    local shipSize = collisionView:size()
    local initialX = random:random(1, shipSize.x)
    local x = initialX
    local bestSurfaceArea = 0
    local bestPos = Vector(x,shipSize.y+10)
    local skipTo = 0
    -- Start from a random X coordinate and iterate mod gridwidth
    for x = initialX, initialX + shipSize.x do
      if x >= skipTo then
        local modX = x % (shipSize.x) + 1
        for y = shipSize.y+1, 1, -1 do
          local surfaceArea, checkX, checkY = calcSurfaceArea(modX,y,room.size:unpack())
          -- This check is absolutely crucial
          --
          -- Are we trying to tetris, or are we trying to squeeze rooms in as tight as possible?
          -- If trying to squeeze them in as tight as possible then omit this check
          -- This is also means we need to to full collision checks, not just the front edge
          if surfaceArea == -1 then
            skipTo = checkX
            break
          end
          -- 
          if surfaceArea > bestSurfaceArea then
            bestPos = Vector(modX,y)
            bestSurfaceArea = surfaceArea
          end
        end
      end
    end
    room.pos = bestPos - Vector(1,1)
    rooms[#rooms+1]=room
    collisionView:add(room.geometry, room.pos)
  end
  
  return rooms
end



local function genRoomsBy4DTetris(random)
  local rooms = {}
  
  local collisionView = Geometry:new()
  
  local left = {len=0,start=0}
  local right = {len=0,start=0}
  local top = {len=0,start=0}
  local bot = {len=0,start=0}
  
  local bounds = {
    left = left,
    right = right,
    top = top,
    bot = bot
  }
  
  local collisionOffset = Vector(-1,-1)
  local function calcSurfaceArea(x,y,width, height)
    x = x - collisionOffset.x
    y = y - collisionOffset.y
    local sum = 0
    
    for checkY = y-1, y+height do
      if collisionView:get(x-1, checkY) then
        sum = sum + 1
      end
      if collisionView:get(x+width, checkY) then
        sum = sum + 1
      end
    end
    
    for checkX = x, x+width-1 do
      if collisionView:get(checkX, y-1) then
        sum = sum + 1
      end
      if collisionView:get(checkX, y+width) then
        sum = sum + 1
      end
    end
    
    return sum
  end
  
  local function addToBounds(tbl, idx, val, min_max)
    if not tbl[idx] then
      tbl[idx] = val
      tbl.len = tbl.len + 1
      if idx < tbl.start then
        tbl.start = idx
      end
    else
      tbl[idx] = math[min_max](tbl[idx], val)
    end
  end
  
  local function addRoom(room, pos)
    if not pos then
      print("uh oh")
    end
    room.pos = pos
    for x = room.pos.x, room.pos.x + room.size.x - 1 do
      addToBounds(top, x, room.pos.y, "min")
      addToBounds(bot, x, room.pos.y + room.size.y, "max")
    end
    
    for y = room.pos.y, room.pos.y + room.size.y - 1 do
      addToBounds(left, y, room.pos.x, "min")
      addToBounds(right, y, room.pos.x + room.size.x, "max")
    end
    
    rooms[#rooms+1] = room
    collisionOffset = collisionOffset + collisionView:add(room.geometry, room.pos)
  end
  
  local num_rooms = random:random(4,12)
  local seedRoom = new_room(random:random(1, #roomTypes), random)
  seedRoom.generator_metadata = {
    seed = true
    }
  addRoom(seedRoom, Vector())
  
  local skipped = 0
  for i = 1, num_rooms do
    local room = new_room(random:random(1, #roomTypes), random)
    
    local dirIndex = random:random(1,4)
    
    if i < num_rooms * (3/4) then
      dirIndex = random:random(1,2)
    else
      dirIndex = random:random(3,4)
    end
    
    local direction = ({"left", "right", "top", "bot"})[dirIndex]
    local xy = ({"y", "y", "x", "x"})[dirIndex]
    local obstacleSign = ({1,-1,1,-1})[dirIndex]
    local posOffset = ({Vector(-room.size.x, 0), Vector(), Vector(0, -room.size.y), Vector()})[dirIndex]
    
    local pos
    
    local skipTo = 0
    local bound = bounds[direction]
    local storeX
    local randomOffset = random:random(bound.start, bound.start + bound.len - 1)
    
    local bestArea, bestPos
    bestArea = 0
    
    for x = 0, bound.len do
      x = ((x + randomOffset) % bound.len) + bound.start
      storeX = x
      if true or x >= skipTo then
        local placementWorks = true
        for check = x, x+room.size[xy]-1 do
          -- Calculates the directional shift between two edges of the wall
          -- A negative shift implies an outcropping == an obstacle in the way of trying to nestle
          -- this room into a gap in the wall.
          if not bound[x] then
            print()
          end
          if obstacleSign * ((bound[check] or 0) - bound[x]) < 0 then
            -- The gap isn't big enough to contain this room!
            --skipTo = check
            if skipTo == bound.start + bound.len - 1 then
              print()
            end
            placementWorks = false
            break
          end
        end

        if placementWorks then
          local pos
          if dirIndex < 3 then
            pos = Vector(bound[x], x)
          else
            pos = Vector(x, bound[x])
          end
          pos = pos + posOffset
          local surface = calcSurfaceArea(pos.x, pos.y, room.size.x, room.size.y)
          if surface > 0 then
            if surface > bestArea then
              bestArea = surface
              bestPos = pos
            end
          end
        end
      end
    end
    if not bestPos then
    end
    if bestPos then
      room.generator_metadata = {
        direction = direction,
        bestArea = bestArea
      }
      addRoom(room, bestPos)
    else
      skipped = skipped + 1
    end
  end
  print("skipped "..tostring(skipped).." rooms")
  return rooms
end

local function roomBounds(rooms)
  local tl,br

  for i = 1,#rooms do
    if rooms[i] then
      local current = rooms[i].pos
      if tl then
        if current.x < tl.x then
          tl.x = current.x
        end
        if current.y < tl.y then
          tl.y = current.y
        end
      else
        tl = current:clone()
      end
      if br then
        if current.x + rooms[i].size.x > br.x then
          br.x = current.x + rooms[i].size.x 
        end
        
        if current.y + rooms[i].size.y > br.y then
          br.y = current.y + rooms[i].size.y
        end
      else
        br = current + rooms[i].size
      end
    end
  end
  
  local center = (br-tl)/2
  
  tl = tl - Vector(1,1)
  

  return tl, br, center
end

local function generate(seed)
  local random = love.math.newRandomGenerator(seed)
  local rooms = genRoomsBy4DTetris(random)
  
  local tl, br = roomBounds(rooms)
  
  -- Offset rooms so that their pos are relative to the top left
  for i = 1, #rooms do
    rooms[i].pos = rooms[i].pos - tl
  end
  
  -- Calculate adjacency matrix for all the rooms
  local doorMatrix, to_merge = roomAdjacency(rooms, random)
  
  -- NOW LEAVING THE GRID
  --
  -- Combine rooms that are adjacent and of the same type
  mergeRooms(rooms, to_merge, doorMatrix)
  
  -- Store the geometry of the spaceship as a whole
  --
  -- Useful for hull generation, as well as a fast lookup for room collision detection
  local shipGeometry = TileGrid:new()
  
  for id, room in ipairs(rooms) do
    local size = room.geometry:size()
    for x = 1, size.x do
      for y = 1, size.y do
        if room.geometry:get(x, y) then
          shipGeometry:set(x+room.pos.x, y+room.pos.y, id)
        end
      end
    end
  end
  
  return {rooms=rooms, doorMatrix=doorMatrix, shipTiles=shipGeometry}
end

return {generate=generate, roomTypes = roomTypes}