Class = require "lib.inherit.composition".Class
Vector = require "vector"
Queue = require "lib.deque.deque".new

HC = require "lib.HC"

if arg[#arg] == "-debug" then require("mobdebug").start() end
require "utils"

World = require "world"
Entity = require "entity"

require "system"
require "component"

love.graphics.setDefaultFilter("nearest", "nearest")

require "components"
local systems = require "systems"
local templates = require "templates"

local generate = require "generator.ship_generator".generate

function love.load()
  stars = {}
  FUDGE = 200
  for i = 1, 300 do
    stars[i] = Vector(love.math.random(-FUDGE/2,love.graphics.getWidth()+FUDGE/2), love.math.random(-FUDGE/2,love.graphics.getHeight()+FUDGE/2))
  end
  
  PRE_GEN = {}
  for i = 1, 20 do
    PRE_GEN[i] = generate(i)
  end
  
  --spaceshipThread = love.thread.newThread("spaceship_thread.lua")
  --spaceshipThread:start(1) -- 1 spaceship per second
  
  FPSHeight = 50
  FPSWidth = 100
  
  FPSCanvas = love.graphics.newCanvas(FPSWidth, FPSHeight)
  sidx = 0
  
  world = World()
  
  for i = 1, #systems do
    world:addSystem(systems[i])
  end
  
  flame = {
    position = Position({pos = Vector()}),
    spawn = function()
      local e = {
        position = {pos = Vector(), r=love.math.random(2*math.pi)},
        rect = {width = love.math.random() * 10 + 5, height = love.math.random() * 10 + 5},
        --triangle = {size = love.math.random() * 10 + 5},
        physics = {
          vel = Vector(love.math.random() * 5 - 2.5, love.math.random() * -50),
          accel = Vector(0, -10)
        },
        timedDeath = {
          timer = 0,
          life = love.math.random(3,5),
        },
        spin = {speed=love.math.random()*6-3},
        colour = {0,1,1},
        fade = {
          a = ({{1,.5,0},{.7,.5,.2},{.7,0,0}})[love.math.random(1,3)],
          b = {.8,.8,.8,.05},
        }
      }
      e.fade.life = e.timedDeath.life
      e.fade.timer = love.math.random() * e.fade.life
      return e 
    end,
    timedSpawn = {
      timer = 0,
      rate = 0.005,
    },
    spawnRadius = {
      outer = 10,
    },

  }

  spark = {
    position = Position{},
    spawn = function()
      local tbl = clone(flame)
      tbl.timedDeath = {timer = 0, life=10}
      return tbl
    end,
    dot = {radius = 2},
    colour = {.8,.8,0}
  }
  
  cursor = {
    position = Position({}),
    followMouse = true,
    spawn = function()
      local tbl = clone(spark)
      tbl.physics = {
        vel = Vector(love.math.random(30,40) * (love.math.random() > 0.5 and -1 or 1), -love.math.random(50,60)),
        accel = Vector(0, 100),
      }
      
      local life = love.math.random()*2
      
      tbl.delayedSpawn = {timer = 0, life=life}
      tbl.dieOnSpawn = true
      
      return tbl
    end,
    spawnOnClick = true,
    multiplySpawn = 8
  }
  
  firework_shell = function(vel, numShells)
    local colour = {love.math.random(), love.math.random(), love.math.random()}
    local e = {
      position = Position({}),
      physics = Physics{vel=vel,accel=Vector(0,20)},
      dot = {radius = 2},
      fade = {
        a = colour,
        b = {0.3,0.3,0.3,0},
        timer = 0,
        life = 3
      },
    }
    
    if numShells > 0 then
      e.spawn = function()
        local vel = e.physics.vel + Vector(love.math.random()-0.5, love.math.random()-0.5) * 50
        return firework_shell(vel, love.math.random(0,math.floor(numShells/2)))
      end
      e.multiplySpawn = numShells
      e.delayedSpawn = DelayedSpawn{life = 3}
      e.dieOnSpawn = true
    else
      e.timedDeath = TimedDeath{life = 3}
    end
    
    return e
  end
  
--  cursor = {
--    position = Position({}),
--    followMouse = true,
--    spawn = function()
--      return firework_shell(Vector(0,-150), 8)
--    end,
--    spawnOnClick = true
--  }
  
--   component templates are a good idea for default values like Vector()
  
  spaceship = {
    position = Position {pos=Vector(100,100)},
    colour = {0.3,0,0},
    --rect = {width=100, height=100},
    --triangle = {size = 50},
    dot = {radius = 25},
    circleCollider = {radius = 25},
    physics = {vel = Vector()},
    jetpackMovement = {speed=200},
    keyboardInput = {axes={j="left", l="right", k="down", i="up"}},
    input = Input(),
    domain = {
      backup = {},
      components = {
        friction = {strength=100},
      }
    },
    --spin = {speed = 2*math.pi},
  }
  
  player = {
    position = Position{pos=Vector(300,290)},
    colour = {1,0,0},
    dot = {radius=3},
    collider = HC.circle(0,0,3),
    physics = Physics{},
    jetpackMovement = {speed=200},
    keyboardInput = {axes={a="left", d="right", s="down", w="up"}, e="interact", ["="]="zoom_in", ["-"]="zoom_out"},
    --followAI = {target = cursor},
    input = {direction = Vector()},
    camera = {zoom = 1},
    domainTraveller = true,
    spawn = function(self)
      return clone(flame)
    end,
    --precisionTarget = {granularity = 1000}, -- uncomment to add world-shifting for precision errors
  }
  
  player.collider.entity = player
  
  campfire = {
    position = Position{},
    --attached = {parent=spaceship, relative=Position{pos=Vector(5,5)}},
    colour = {0,1,0},
    dot = {radius = 5},
    circleCollider = {radius = 7},
    dieOnSpawn = true,
    attachOnSpawn = "parent",
    spawn = function() return clone(flame) end,
    interactFireEvent = {eventName = "spawn"},
    domainTraveller = true,
  }
  
  function makeSpaceship(pos, vel)
    local dir = vel.x > 0
    local e = {
      position = Position{pos=pos},
      physics = {vel=vel},
      rect = {width = love.math.random(3,15)*6, height=love.math.random(3,10)*6},
      colour = {0.4, 0,0},
    }
    
    return e
  end
  
  SHIP_SPEED = 200
  
  leftSpawner = {
    spawn = function()
      local spaceshipParts = love.thread.getChannel("spaceshipGen"):pop()
      
      if spaceshipParts then
        spaceshipParts[1].colour = {0,1,0}
      else
        spaceshipParts = templates.Spaceship()
        spaceshipParts[1].colour = {1,0,0}
      end
      local position = spaceshipParts[1].position
      position.pos = Vector(position.pos)
      spaceshipParts[2].attached.relative.pos = Vector(-5,-5)
      spaceshipParts[3].attached.relative.pos = Vector(5,-5)
      spaceshipParts[1].physics.vel = Vector(50,0)
      
      -- metatable hack
      spaceshipParts[1].physics.accel = Vector()
      
      return unpack(spaceshipParts)
    end,
    timedSpawn = TimedSpawn{rate = .25},
    position = Position{pos = Vector(-10, 300)},
  }
  
  leftSpawner = {
    position = Position{},
    colour = {0,1,1},
    dot = {radius=2},
    attached = {
      parent = player,
      relative = Position{pos=Vector(-900, -100)},
    },
    spawn = function(self)
      if player.physics.vel.x > 0 then 
        pos = Vector(-2*self.attached.relative.pos.x, 0)
      else
        pos = Vector(0, 0)
      end
      vel = Vector(SHIP_SPEED,0)
      return unpack(templates.Spaceship(pos, vel))
    end,
    timedSpawn = TimedSpawn{rate = .5},
    streamSpawner = {
      avgWidth = 60,
    },
    relativeStreamVelocity = {
      entity = player,
      vel = SHIP_SPEED
    },
    keyboardInput = {i="increaseVelocity", k="decreaseVelocity", j="decreaseWidth", l="increaseWidth", axes={}},
  }
  
  rightSpawner = clone(leftSpawner)
  
  rightSpawner.relativeStreamVelocity.vel = -SHIP_SPEED
  rightSpawner.attached.relative = Position{pos=Vector(900, 100)}
  rightSpawner.spawn = function(self)
    if player.physics.vel.x < 0 then 
      pos = Vector(-2*self.attached.relative.pos.x, 0)
    else
      pos = Vector(0, 0)
    end
    vel = Vector(-SHIP_SPEED,0)
    return unpack(templates.Spaceship(pos, vel))
  end
  
   rightSpawner = {
    position = Position{},
    colour = {0,1,1},
    dot = {radius=2},
    attached = {
      parent = player,
      relative = Position{pos=Vector(900, 100)},
    },
    spawn = function(self)
      if player.physics.vel.x < 0 then 
        pos = Vector(-2*self.attached.relative.pos.x, 0)
      else
        pos = Vector(0, 0)
      end
      vel = Vector(-SHIP_SPEED,0)
      return unpack(templates.Spaceship(pos, vel))
    end,
    timedSpawn = TimedSpawn{rate = .5},
    streamSpawner = {
      avgWidth = 60,
    },
    relativeStreamVelocity = {
      entity = player,
      vel = -SHIP_SPEED
    },
    keyboardInput = {i="increaseVelocity", k="decreaseVelocity", j="decreaseWidth", l="increaseWidth", axes={}},
  }
  
  lanes = {
  -- pos,           dir,        speed, dist
    {Vector(0,-100), Vector(1,0), 200, 200},
    {Vector(0,300), Vector(1,0), 400, 200},
    {Vector(0,600), Vector(1,0), 500, 1000},
    {Vector(0,1000), Vector(1,0), 1200, 200},
  }
  
  for i = 1, #lanes do
    local lane = lanes[i]
    
    lanes[i] = templates.Lane(lane[1], lane[2], lane[3], lane[4], player)[1]
    world:addEntity(lanes[i])
  end
  
  world:addEntity(player)
  world:addEntity(cursor)
end

function love.update(dt)
  deltaTime = dt
  
  world:addEvent(nil, "preprocess", {dt=dt})
  world:process()
  
  world:addEvent(nil, "update", {dt=dt})
  world:process()
  
  -- Is this a hack?
  world:addEvent(nil, "postprocess", {dt=dt})
  world:process()
end

initialStarVel = Vector(-1000,0) 
viewOffset = Vector()

function sigmoid(x, mean,  k)
  return 1 / (1 + math.exp(-k * (x - mean)))
end

function love.draw()
  
  starVel = initialStarVel - player.physics.vel
  viewOffset = viewOffset + starVel * deltaTime
  local warpFactor = sigmoid(starVel:len(), initialStarVel:len() + 1000, 0.01)
  
  love.graphics.setColor(lerpColour(warpFactor, {1,1,1}, {0.35,0.36,1}))
  
  for n = 1,3 do
    love.graphics.setPointSize(n)
    for i = n, #stars, 3  do
      love.graphics.setPointSize(n)
      love.graphics.setLineWidth(n)
      -- TODO: replace with points(unpack(stars)) and love.translate
      local star = stars[i]
      local drawstar = star + viewOffset * (1/10) * n--(stardir * ELAPSED_TIME * n * STAR_SPEED)
--      drawstar = drawstar + Vector(1,1) * n
      FUDGE = 200
      drawstar.x = (drawstar.x % (love.graphics.getWidth() + FUDGE)) - FUDGE / 2
      drawstar.y = (drawstar.y % (love.graphics.getHeight() + FUDGE)) - FUDGE / 2
      
      local tail = drawstar + starVel:normalized() * warpFactor * 30 * n -- 100 pixel max for the tail
      
      love.graphics.line(drawstar.x, drawstar.y, tail.x, tail.y)
      love.graphics.points(drawstar.x, drawstar.y)
    end
  end
  
  world:addEvent(nil, "preDraw", {})
  world:process()
  
  world:addEvent(nil, "draw", {})
  world:process()
  
  world:addEvent(nil, "postDraw", {})
  world:process()
  
  DEBUG = true
  if DEBUG then
  
  -- from zorg @ discord
  -- spectograph is a canvas the same size as the window
  -- sidx is a column offset in the spectograph canvas
  -- H is window height, W is window width

  -- this in love.draw
  love.graphics.setCanvas(FPSCanvas)
  love.graphics.push('all')
  --love.graphics.setScissor(0,0,1,FPSHeight) -- scroll mode
  love.graphics.setScissor(sidx,0,1,FPSHeight) -- trace mode
  love.graphics.clear(0,0,0,0)
  love.graphics.pop()

  -- draw 1 column of data
  love.graphics.setColor(1,0,0)
  local fps = (1/deltaTime)
  local yPos = FPSHeight * (fps/70)
  love.graphics.rectangle("fill", sidx, FPSHeight - yPos, 1, FPSHeight)

  sidx = (sidx + 1) % (FPSWidth)
  love.graphics.setCanvas()
  love.graphics.setColor(1,1,1,1)
  love.graphics.setScissor(0,0,FPSWidth,FPSHeight)
  love.graphics.draw(FPSCanvas, FPSWidth-sidx, 0) -- scroll mode
  love.graphics.draw(FPSCanvas, 0-sidx, 0) -- (^ takes two draw calls)
  love.graphics.setScissor()
  --love.graphics.draw(FPSCanvas, 0, 0) -- trace mode
  
  love.graphics.setColor(1,1,1)
  love.graphics.print(tostring(1/deltaTime).." fps", FPSWidth)
  love.graphics.print("processing "..tostring(#world.entities).." entities", FPSWidth,20)
  love.graphics.print("player.vel="..tostring(player.physics.vel)..", player.pos="..tostring(player.position.pos),FPSWidth,30)
  if player.attached then
    love.graphics.print("player.relativeVelocity="..tostring(player.attached.relativePhysics.vel),FPSWidth,40)
  end
  
  end
end

function love.mousemoved(x,y)
  world:addEvent(nil, "mousemoved", {pos=Vector(x,y)})
end

function love.keypressed(key)
  world:addEvent(nil, "keypressed", {key=key})
end

function love.mousepressed(x,y,button)
  world:addEvent(nil, "mousepressed", {x=x, y=y, button=button})
end