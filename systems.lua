local s = require "system".makeProcessingSystemClass

AccelerationSystem = s{"physics"}

function AccelerationSystem:filter(entity)
  return entity.physics and entity.physics.accel and entity.physics.vel
end

function AccelerationSystem:onUpdate(entity, eventArgs)
  local dt = eventArgs.dt
  local physics = entity.physics
  physics.vel = physics.vel + physics.accel * dt
end

VelocitySystem = s{"physics", "position"}

function VelocitySystem:filter(entity)
  return entity.physics and entity.physics.vel and entity.position
end

-- TODO
--
-- Implement relative physics too so that player velocity is correctly read even when in a spaceship
function VelocitySystem:onUpdate(entity, eventArgs)
  local dt = eventArgs.dt
  local position, physics
  -- GROSS COUPLING
  -- IS ONLY NECCESSARY FOR THINGS WRITING TO POSITION
  if entity.attached then
    position = entity.attached.relative
    physics = entity.attached.relativePhysics
  else
    position = entity.position
    physics = entity.physics
  end
  position.pos = position.pos + physics.vel * dt
end

AttachedSystem = s{"position", "attached"}

function AttachedSystem:onUpdate(entity)
  entity.position.pos = entity.attached.parent.position.pos + entity.attached.relative.pos
end

RelativeVelocity = s{"attached", "physics"}

function RelativeVelocity:onUpdate(entity)
  entity.physics.vel = entity.attached.parent.physics.vel + entity.attached.relativePhysics.vel
end

Friction = s{"physics", "friction"}

function Friction:onUpdate(entity, eventArgs)
  local dt = eventArgs.dt
  local physics = entity.physics
  local friction = entity.friction
  
  physics.vel = physics.vel - (physics.vel:normalized() * math.min(physics.vel:len(), friction.strength*dt))
end

DotSystem = s{"dot", "position"}

function DotSystem:onDraw(entity)
  local pos, dot = entity.position.pos, entity.dot
  love.graphics.setColor(entity.colour or {1,0,0})
  love.graphics.circle("fill", pos.x, pos.y, dot.radius)
end

SpawnSystem = s{"spawn"}


function SpawnSystem:onSpawn(entity, eventArgs)
  
  if eventArgs.e then return true end
  -- spawn is a method that returns an entity
  -- FIXME: This mixes components and behaviour
  local toSpawn = {entity:spawn()}
  for i = 1, #toSpawn do
    local e = toSpawn[i]
    
    -- For future onSpawn handlers
    local args = clone(eventArgs)
    args.e = e
    
    world:addEntity(e)
    world:addEvent(entity, "spawn", args)
    world:addEvent(e, "created", {by=entity})
    world:addEvent(e, "update", {dt=0})
    
  end
  return false
end

SpawnRelativeSystem = s{"spawn", "position"}

function SpawnRelativeSystem:filter(entity)
  return (not entity.spawnAbsolute) and entity.spawn and entity.position
end

function SpawnRelativeSystem:onSpawn(entity, eventArgs)
  local e = eventArgs.e
  e.position.pos = entity.position.pos + e.position.pos
end

SpawnOnClick = s{"spawn", "spawnOnClick"}

function SpawnOnClick:onMousepressed(entity, eventArgs)
  world:addEvent(entity, "spawn", {})
end

TimedSpawnSystem = s{"spawn", "timedSpawn"}

function TimedSpawnSystem:onUpdate(entity, eventArgs)
  local dt = eventArgs.dt
  local timedSpawn = entity.timedSpawn
  timedSpawn.timer = timedSpawn.timer + dt
  if timedSpawn.timer > timedSpawn.rate then
    world:addEvent(entity, "spawn")
    timedSpawn.timer = 0
  end
end

TimedDeathSystem = s{"timedDeath"}

function TimedDeathSystem:onUpdate(entity, eventArgs)
  local timedDeath = entity.timedDeath
  timedDeath.timer = timedDeath.timer + eventArgs.dt
  
  if timedDeath.timer > timedDeath.life then
    world:removeEntity(entity)
  end
end

SpawnRadius = s{"spawn", "spawnRadius"}

function SpawnRadius:onSpawn(entity, eventArgs)
  local inner = entity.spawnRadius.inner or 0
  local outer = entity.spawnRadius.outer
  
  local offset = Vector.randomDirection(inner, outer)
  
  local spawned = eventArgs.e
  spawned.position.pos  = spawned.position.pos + offset
end

RectSystem = s{"rect", "position"}

function RectSystem:onDraw(entity)
  local rect = entity.rect
  local position = entity.position
  love.graphics.push()
  love.graphics.setColor(entity.colour)
  love.graphics.translate(position.pos.x, position.pos.y)
  love.graphics.rotate(position.r or 0)
  --love.graphics.translate(position.pos.x+rect.width, position.pos.y+rect.height)
  love.graphics.rectangle("fill", 0,0, rect.width, rect.height)
  love.graphics.pop()
end

Triangle = s{"triangle", "position"}

function Triangle:onDraw(entity)
  local colour = entity.colour or {1,0,0}
  local size = entity.triangle.size
  local pos = entity.position.pos
  love.graphics.setColor(colour)
  love.graphics.push()
  love.graphics.translate(pos.x, pos.y)
  love.graphics.rotate(entity.position.r)
  love.graphics.polygon("fill", -size/2, -size/3, size/2, -size/3, 0, (2/3)*size)
  love.graphics.pop()
end

Speeen = s{"spin", "position"}

function Speeen:onUpdate(entity, eventArgs)
  local dt = eventArgs.dt
  
  entity.position.r = entity.position.r + (entity.spin.speed * dt)
end

Fade = s{"fade"}

function lerpColour(t, a, b)
  local red = a[1] + t * (b[1] - a[1])
  local green = a[2] + t * (b[2] - a[2])
  local blue = a[3] + t * (b[3] - a[3])
  local alpha = (a[4] or 1) + t * ((b[4] or 1) - (a[4] or 1))
  return {red,green,blue,alpha}
end

function clamp(t, min, max)
  return math.max(math.min(t,max), min)
end

function Fade:onUpdate(entity, eventArgs)
  local fade = entity.fade
  fade.timer = fade.timer + eventArgs.dt
  
  local t = fade.timer / fade.life
  t = clamp(t,0,1)
  
  entity.colour = lerpColour(t, fade.a, fade.b)
end

DelayedSpawnSystem = s{"spawn", "delayedSpawn"}

function DelayedSpawnSystem:onUpdate(entity, eventArgs)
  local delayedSpawn = entity.delayedSpawn
  
  delayedSpawn.timer = delayedSpawn.timer + eventArgs.dt
  
  if delayedSpawn.timer >= delayedSpawn.life then
    --entity:removeComponenet("delayedSpawn")
    entity.delayedSpawn = nil
    world:addEvent(entity, "spawn")
  end
end

MultiplySpawn = s{"spawn", "multiplySpawn"}

function MultiplySpawn:onSpawn(entity, eventArgs)
  if not eventArgs.multiplied then
    eventArgs.multiplied = true
    for i = 1, entity.multiplySpawn do
      world:addEvent(entity, "spawn", eventArgs)
    end
    return false
  end
end

AttachOnSpawn = s{"spawn", "attachOnSpawn"}

function AttachOnSpawn:onSpawn(entity, eventArgs)
  local e = eventArgs.e
  local attachOnSpawn = entity.attachOnSpawn
  local parent
  if attachOnSpawn == "self" then
    parent = entity
  elseif attachOnSpawn == "parent" then
    if entity.attached then
      parent = entity.attached.parent
    else
      return
    end
  else
    parent = attachOnSpawn
  end
  e.attached = {parent=parent, relative=Position{pos=e.position.pos - entity.position.pos}}
end

DieOnSpawn = s{"spawn", "dieOnSpawn"}

function DieOnSpawn:onSpawn(entity)
  world:addEvent(entity, "kill")
end

-- This system exists so that "kill" events can happen after multiplied spawn events. Maybe there should be a "kill at the end of the frame" event instead that just adds entity to _toremove?
Death = s{}

function Death:filter()
  return true
end

function Death:onKill(entity)
  world:removeEntity(entity)
end

KeyboardInputSystem = s{"keyboardInput"}

function KeyboardInputSystem:onKeypressed(entity, eventArgs)
  local keyboardInput = entity.keyboardInput
  local inputName = keyboardInput[eventArgs.key]
  if inputName then
    world:addEvent(entity, "input", {inputName=inputName})
  end
end

-- maybe replace with a mapping on the keyboard input directly from key to vector. Then people can map their own keys for diagonal movement?
KeyboardInputSystem.axes = {
  left = Vector(-1,0),
  right = Vector(1,0),
  down = Vector(0,1),
  up = Vector(0,-1),
}

function KeyboardInputSystem:onUpdate(entity, eventArgs)
  local keyboardInput = entity.keyboardInput
  local axes = keyboardInput.axes
  
  local input = entity.input
  -- TODO: Should KeyboardAxes controller be a separate component/system?
  if axes and input then
    local dir = Vector()
    for key, direction in pairs(axes) do
      if love.keyboard.isDown(key) then
        dir = dir + self.axes[direction]
      end
    end
    
    input.direction = (dir + input.direction):normalized()
  end
end

JetpackMovement = s{"jetpackMovement", "physics", "input"}

function JetpackMovement:onUpdate(entity, eventArgs)
  local jp = entity.jetpackMovement
  entity.physics.vel = entity.physics.vel + (entity.input.direction:normalized() * eventArgs.dt * jp.speed)
end

FollowAI = s{"position", "input", "followAI"}

function FollowAI:onUpdate(entity, eventArgs)
  local target = entity.followAI.target
  local input = entity.input
  
  direction = target.position.pos - entity.position.pos
  
  input.direction = (input.direction + direction):normalized()
end

DetachSystem = s{"position", "attached"}

function DetachSystem:onDetach(entity, eventArgs)
  local physics = entity.physics
  local attached = entity.attached
  local parent = attached.parent
  if physics and attached.parent.physics then
    physics.vel = physics.vel + attached.parent.physics.vel
  end
  entity.position.pos = attached.parent.position.pos + attached.relative.pos
  entity.attached = nil
end

InputSystem = s{"input"}

function InputSystem:onPreprocess(entity)
  entity.input.direction = Vector()
end

PrecisionTarget = s{"position", "precisionTarget"}

function PrecisionTarget:onPostprocess(entity, eventArgs)
  local granularity = entity.precisionTarget.granularity
  
  local pos = entity.position.pos
  
  local x = math.floor(math.abs(pos.x / granularity)) * granularity * (pos.x > 0 and 1 or -1) 
  local y = math.floor(math.abs(pos.y / granularity)) * granularity * (pos.y > 0 and 1 or -1) 
  
  if x ~= 0 or y ~= 0 then
    world:addEvent(nil, "precisionCenter", {offset = Vector(x,y)})
  end
end

PrecisionCenteringSystem = s{"position"}

function PrecisionCenteringSystem:onPrecisionCenter(entity, eventArgs)
  entity.position.pos = entity.position.pos - eventArgs.offset
end

CameraSystem = s{"position", "camera"}

function CameraSystem:onPreprocess(entity)
  self.transform = love.math.newTransform(entity.position.pos.x, entity.position.pos.y, 0, entity.camera.zoom):apply(
    love.math.newTransform(love.graphics.getWidth()/2, love.graphics.getHeight()/2))
end

function CameraSystem:onPreDraw(entity)
  love.graphics.push()
  
  love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  love.graphics.scale(entity.camera.zoom)
  love.graphics.translate((-entity.position.pos):unpack())
  
end

function CameraSystem:onPostDraw(entity)
  love.graphics.pop()
end

FollowMouseSystem = s{"followMouse"}

function FollowMouseSystem:onMousemoved(entity, eventArgs)
  entity.position.pos = Vector(CameraSystem.transform:transformPoint(eventArgs.pos:unpack()))
end

DomainSystem = s{"position", "domain"}

function DomainSystem:onEnterDomain(entity, eventArgs)
  local domain = entity.domain
  local e = eventArgs.entering
  
  local backup = {}
  
  for k,v in pairs(domain.components) do
    backup[k] = e[k]
    e[k] = v
  end
  backup.attached = e.attached
  domain.backup[e] = backup
  
  -- Maybe a FIXME. Should the idea of domains be separated from parenting?
  e.attached = Attached{parent=entity, relative=Position{pos=e.position.pos-entity.position.pos}}
end

function DomainSystem:onExitDomain(entity, eventArgs)
  -- TODO: Standardize the name for an event that references another entity. This way onInteract could directly pass on the info to onEnterDomain
  local e = eventArgs.exiting
  local domain = entity.domain
  
  local backup = domain.backup[e]
  assert(backup)
  for key,_ in pairs(domain.components) do
    e[key] = backup[key]
  end
  domain.backup[e] = nil
  -- support nesting
  e.attached = backup.attached
end

VelocityTransferSystem = s{"position", "physics", "domain"}

function VelocityTransferSystem:onEnterDomain(entity, eventArgs)
  local e = eventArgs.entering
  if e.physics then
    e.attached.relativePhysics.vel = e.physics.vel - entity.physics.vel
  end
end

function VelocityTransferSystem:onExitDomain(entity, eventArgs)
  local e = eventArgs.exiting
  if e.physics then
    e.physics.vel = e.attached.relativePhysics.vel + entity.physics.vel
  end
end

DomainColliderSystem = s{"domain"}

--function DomainColliderSystem:onCollision(entity, eventArgs)
--  world:addEvent(entity, "enterDomain", {entering=eventArgs.collider})
--end

--function DomainColliderSystem:onCollisionEnded(entity, eventArgs)
--  local exiting = eventArgs.collider
--  if entity.domain.backup[exiting] then
--    world:addEvent(entity, "exitDomain", {exiting=exiting})
--  end
--end

DomainTraveller = s{"domainTraveller"}

--function DomainTraveller:onCollision(entity, eventArgs)
--  local collider = eventArgs.collider
--  if collider.domain then
--    world:addEvent(collider, "enterDomain", {entering=entity})
--  end
--end

DomainEntranceSystem = s{"domainEntrance"}

function DomainEntranceSystem:onInteract(entity, eventArgs)
  world:addEvent(entity.domainEntrance.domain, "enterDomain", {entering=eventArgs.from})
end

DomainExitSystem = s{"domainExit"}

function DomainExitSystem:onInteract(entity, eventArgs)
  world:addEvent(entity.domainExit.domain, "exitDomain", {exiting=eventArgs.from})
end

TeleporterSystem = s{"teleporter"}

function TeleporterSystem:onInteract(entity, eventArgs)
  local pos = entity.teleporter.pos
  
  local e = eventArgs.from
  
  if e.attached then
    
  else
    
  end
end


InteractFireEvent = s{"interactFireEvent"}

function InteractFireEvent:onInteract(entity, eventArgs)
  local interactFireEvent = entity.interactFireEvent
  
  world:addEvent(entity, interactFireEvent.eventName, eventArgs)
end

InteractsSystem = s{"input", "collidingWith"}

function InteractsSystem:onInput(entity, eventArgs)
  local inputName = eventArgs.inputName
  
  if inputName == "interact" then
    for colliding, _ in pairs(entity.collidingWith) do
      world:addEvent(colliding, "interact", {from=entity})
    end
  end
end

PopupText = s{"popup"}

function PopupText:onDraw()
  love.graphics.text()
end

CollisionSystem = s{"position"}

-- FIXME: Replace with tiny.filter
function CollisionSystem:filter(entity)
  return entity.position and
  (entity.circleCollider or entity.rectangleCollider or entity.polygonCollider or entity.compositeCollider)
end

-- This whole thing should be scrapped for different systems for 
-- different collider types

function circularDistance(center, radius, testPos)
  return (testPos - center):len() - radius
end

-- https://gamedev.stackexchange.com/a/100534
-- Naive implementation, doesn't respsect rotation
function rectDistance(topLeft, width, height, testPos)
  local nearest = testPos:clone()
  local max_x, max_y, min_x, min_y = topLeft.x + width, topLeft.y + height, topLeft.x, topLeft.y
  if testPos.x > max_x then nearest.x = max_x
  elseif testPos.x < min_x then nearest.x = min_x end

  if testPos.y > max_y then nearest.y = max_y
  elseif testPos.y < min_y then nearest.y = min_y end
  
  return (testPos - nearest):len()
end

function collides(entity1, entity2)
  if entity1.circleCollider and entity2.circleCollider then
    return circularDistance(entity1.position.pos, entity1.circleCollider.radius, entity2.position.pos) <= entity2.circleCollider.radius
  elseif entity1.circleCollider and entity2.rectangleCollider then
    return rectDistance(entity2.position.pos, entity2.rectangleCollider.width, entity2.rectangleCollider.height, entity1.position.pos) <= entity1.circleCollider.radius
  elseif entity1.rectangleCollider and entity2.circleCollider then
    return collides(entity2, entity1)
  elseif entity1.rectangleCollider and entity2.rectangleCollider then
    return false
  end
end

-- This should use a Quadtree
function CollisionSystem:onUpdate(entity, eventArgs)
  if not entity.collidingWith then entity.collidingWith = {} end
  local collidingWith = entity.collidingWith
  
  for i = 1, #world.entities do
    local other = world.entities[i]
    
    if other ~=entity and self:filter(other) then
      if collides(entity, other) then
        if not collidingWith[other] then
          world:addEvent(entity, "collision", {collider=other})
          collidingWith[other] = true
        end
      elseif collidingWith[other] then
        world:addEvent(entity, "collisionEnded", {collider=other})
        collidingWith[other] = nil
      end
    end
  end
end

DebugDespawner = s{"position"}

function DebugDespawner:onUpdate(entity)
  if math.abs(entity.position.pos.x - player.position.pos.x) > 10000 then
    world:addEvent(entity, "kill")
  end
end

streamSpawner = {
  avgVelocity = 100, --velocity of objects
  avgWidth = 30, -- width of objects
}

StreamSpawner = s{"streamSpawner", "spawn", "timedSpawn"}

function StreamSpawner:onUpdate(entity, eventArgs)
  local streamSpawner = entity.streamSpawner
  -- local vel = player.physics.vel - streamSpawner.avgVelocity
  
  --local throughput = vel / streamSpawner.avgWidth
  local throughput = math.abs(streamSpawner.avgVelocity / streamSpawner.avgWidth)
  -- FIXME: 1/0 is possible here
  entity.timedSpawn.rate = 1/throughput
end

StreamSpawnerController = s{"streamSpawner"}

function StreamSpawnerController:onInput(entity, eventArgs)
  local inputName = eventArgs.inputName
  local streamSpawner = entity.streamSpawner
  if inputName == "increaseVelocity" then
    streamSpawner.avgVelocity = streamSpawner.avgVelocity + 10
  elseif inputName == "decreaseVelocity" then
    streamSpawner.avgVelocity = streamSpawner.avgVelocity - 10
  elseif inputName == "increaseWidth" then
    streamSpawner.avgWidth = streamSpawner.avgWidth + 2
  elseif inputName == "decreaseWidth" then
    streamSpawner.avgWidth = streamSpawner.avgWidth - 2
  end
end

RelativeStreamSpawner = s{"relativeStreamVelocity", "streamSpawner"}

function RelativeStreamSpawner:onUpdate(entity, eventArgs)
  local relative = entity.relativeStreamVelocity
  entity.streamSpawner.avgVelocity = math.abs(relative.entity.physics.vel.x - relative.vel)
end

-- FIXME: Adding an "attached" module should automatically add to a "children" component on the parent
CleanupAttached = s{}

function CleanupAttached:onKill(entity)
  for i = 1, #world.entities do
    local e = world.entities[i]
    
    if e.attached and e.attached.parent == entity then
      world:addEvent(e, "kill")
    end
  end
end

DebugLogCollisions = s{"logCollisions"}

function DebugLogCollisions:onCollision(entity, eventArgs)
  print("collision")
end

function DebugLogCollisions:onCollisionEnded(entity, eventArgs)
  print("collisionEnded")
end

return {CameraSystem, DetachSystem, AccelerationSystem, InputSystem, KeyboardInputSystem, FollowAI, JetpackMovement, VelocitySystem, RelativeVelocity, AttachedSystem, CollisionSystem, Friction, Speeen, Fade, Triangle, RectSystem, DotSystem, MultiplySpawn, SpawnSystem, AttachOnSpawn, SpawnRelativeSystem, SpawnOnClick, SpawnRadius, RelativeStreamSpawner, StreamSpawner, TimedSpawnSystem, DelayedSpawnSystem, FollowMouseSystem, TimedDeathSystem, DieOnSpawn, Death, PrecisionTarget, PrecisionCenteringSystem, InteractsSystem, InteractFireEvent, DomainSystem, DomainColliderSystem, VelocityTransferSystem, DomainTraveller, DomainEntranceSystem, DomainExitSystem, DebugLogCollisions, DebugDespawner, CleanupAttached, StreamSpawnerController}