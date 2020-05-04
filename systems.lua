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

function setVelocity(entity, velocity)
  if entity.attached then
    entity.attached.relativePhysics.vel = velocity - entity.attached.parent.physics.vel
  else
    entity.physics.vel = velocity
  end
end

ColliderMover = s{"position", "collider"}

function ColliderMover:onUpdate(entity, eventArgs)
  entity.collider:moveTo(entity.position.pos:unpack())
end

Friction = s{"physics", "friction"}

function Friction:onUpdate(entity, eventArgs)
  local dt = eventArgs.dt
  local physics = entity.physics
  local friction = entity.friction
  if entity.attached then physics = entity.attached.relativePhysics end
  physics.vel = physics.vel * math.min(1, math.max(0, 1 - (friction.strength * dt)))
end

DotSystem = s{"dot", "position"}

function DotSystem:onDraw(entity)
  local pos, dot = entity.position.pos, entity.dot
  love.graphics.setColor(entity.colour or {1,0,0})
  love.graphics.circle("fill", pos.x, pos.y, dot.radius)
end

SpawnSystem = s{"spawn"}

function SpawnSystem:onSpawn(entity, eventArgs)
  if eventArgs.e then return false end
  -- spawn is a method that returns an entity
  -- FIXME: This mixes components and behaviour
  local toSpawn = {entity:spawn()}
  
  for i = 2, #toSpawn do
    local child = toSpawn[i]
    
    -- For future onSpawn handlers
    local args = clone(eventArgs)
    args.e = child

      args.pos = child.position.pos

    world:addEntity(child)
    --world:addEvent(entity, "spawn", args)
    world:addEvent(child, "created", {by=entity})
  end
  
  local parent = toSpawn[1]
  
  
  local args = (eventArgs)
  assert(parent ~= nil)
  args.e = parent
  if not args.pos then
    args.pos = parent.position.pos
  end
  world:addEntity(parent)
  world:addEvent(entity, "spawn", args)
  world:addEvent(parent, "created", {by=entity})
end

SpawnRelativeSystem = s{"spawn", "position"}

function SpawnRelativeSystem:filter(entity)
  return (not entity.spawnAbsolute) and entity.spawn and entity.position
end

function SpawnRelativeSystem:onSpawn(entity, eventArgs)
  eventArgs.pos = entity.position.pos + eventArgs.pos
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
  
  eventArgs.pos  = eventArgs.pos + offset
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
  setVelocity(entity, entity.physics.vel + (entity.input.direction:normalized() * eventArgs.dt * jp.speed))
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
    physics.vel = entity.attached.relativePhysics.vel + attached.parent.physics.vel
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

function CameraSystem:onInput(entity, eventArgs)
  local inputName = eventArgs.inputName
  local camera = entity.camera
  
  if inputName == "zoom_in" then
    camera.zoom = camera.zoom + 0.2
  elseif inputName == "zoom_out" then
    camera.zoom = camera.zoom - 0.2
  end
end

FollowMouseSystem = s{"followMouse"}

function FollowMouseSystem:onMousemoved(entity, eventArgs)
  entity.position.pos = eventArgs.pos --(CameraSystem.transform:transformPoint(eventArgs.pos:unpack()))
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
    setVelocity(e, e.physics.vel)
  end
end

function VelocityTransferSystem:onExitDomain(entity, eventArgs)
  local e = eventArgs.exiting
  if e.physics then
    e.physics.vel = entity.physics.vel
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
    for collider, delta in pairs(entity.collidingWith) do
      world:addEvent(collider.entity, "interact", {from=entity})
    end
  end
end

PopupText = s{"popup"}

function PopupText:onDraw()
  love.graphics.text()
end

CollisionSystem = s{"position", "collider"}

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

function CollisionSystem:onUpdate(entity, eventArgs)
  -- TODO: replace with Collider.dep = "CollidingWith"
  if not entity.collidingWith then entity.collidingWith = {} end
  local oldCollidingWith = entity.collidingWith
  
  local newCollidingWith = HC.collisions(entity.collider)
  
  for other, delta in pairs(newCollidingWith) do
    if not oldCollidingWith[other] then
      world:addEvent(entity, "collision", {collider=other.entity})
    end
  end
  
  for other, delta in pairs(oldCollidingWith) do
    if not newCollidingWith[other] then
      world:addEvent(entity, "collisionEnded", {collider=other.entity})
    end
  end
  
  entity.collidingWith = newCollidingWith
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
      assert(not e.lineSpawner)
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

LineSpawnerSystem = s{"lineSpawner", "spawn", "position"}

SPAWN_DIST = 1000
DESPAWN_DIST = 2000

-- https://stackoverflow.com/a/51906100
function nearestPointToLine(origin, direction, point)
  local lhs = point - origin
  
  local dot = lhs * direction
  return origin + (direction * dot)
end

-- TODO: Can probably just sort over the entire swarm to find right and left? Then can boid it up

function LineSpawnerSystem:onUpdate(entity)
  -- The entity that we're tracking
  local target = entity.lineSpawner.target
  local swarm = entity.lineSpawner.swarm
  local avgDist = entity.lineSpawner.avgDist
  local line = entity.lineSpawner.line

  local leftmost = swarm:peek_left()
  local rightmost = swarm:peek_right()
  
  local closest = nearestPointToLine(entity.position.pos, line.dir, target.position.pos)
  
  if not leftmost then
    leftmost = closest
  else leftmost = leftmost.position.pos end
  
  if not rightmost then
    rightmost = closest
  else rightmost = rightmost.position.pos end
  
  -- SPAWN ITERATIONS
  while (leftmost - closest):len() < SPAWN_DIST do
    local dist = (leftmost - closest) * line.dir
    local offset = (dist - avgDist) * line.dir
    local newPos = closest + offset
    world:addEvent(entity, "spawn", {pos=newPos, push="left"})
    leftmost = newPos
  end
  
  while (rightmost - closest):len() < SPAWN_DIST do
    local dist = (rightmost - closest) * line.dir
    local offset = (dist + avgDist) * line.dir
    local newPos = closest + offset
    world:addEvent(entity, "spawn", {pos=newPos, push="right"})
    rightmost = newPos
  end
  
  -- DESPAWN ITERATIONS
  
  while (leftmost - closest):len() > DESPAWN_DIST do
    local toKill = swarm:pop_left()
    if toKill then
      assert(not toKill.lineSpawner)
      world:addEvent(toKill, "kill")
    end
    leftmost = swarm:peek_left()
    leftmost = leftmost and leftmost.position.pos or closest
    assert(leftmost.x <= rightmost.x)
  end
  
  while (rightmost - closest):len() > DESPAWN_DIST do
    local toKill = swarm:pop_right()
    if toKill then
      assert(not toKill.lineSpawner)
      world:addEvent(toKill, "kill")
    end
    rightmost = swarm:peek_right()
    if rightmost and not rightmost.position then
      tprint(rightmost)
    end
    rightmost = rightmost and rightmost.position.pos or closest
    assert(rightmost.x >= leftmost.x)
  end
end

-- kinda hacky but idk how else to do it in this event-based system
function LineSpawnerSystem:onSpawn(entity, eventArgs)
  if eventArgs.push then
    local swarm = entity.lineSpawner.swarm
    local e = eventArgs.e
    swarm["push_"..eventArgs.push](swarm, e)
    
    if eventArgs.push == "right" then
      e.swarm = {
        swarm = swarm,
        index = swarm.tail,
      }
    else
      e.swarm = {
        swarm = swarm,
        index = swarm.head,
      }
    end
  end
end

--function LineSpawnerSystem:onDraw(entity)
--  local line = entity.lineSpawner.line
--  local target = entity.lineSpawner.target
--  local closest = nearestPointToLine(entity.position.pos, line.dir, target.position.pos)
  
--  love.graphics.setColor(0,1,0)
--  love.graphics.points(closest.x, closest.y)
--end

SpawnAt = s{"spawn"}

function SpawnAt:onSpawn(entity, eventArgs)
  if eventArgs.pos then
    eventArgs.e.position.pos = eventArgs.pos
  end
end

-- TODO: Rename "swarm" component?
LineBoid = s{"swarm", "boid", "input"}

function LineBoid:onUpdate(entity, eventArgs)
  local swarm = entity.swarm
  local boid = entity.boid
  local steer = Vector()
  for i = swarm.index - 2, swarm.index + 2 do
    local neighbour = swarm.swarm[swarm.index]
    
    if neighbour then
      local delta = entity.position.pos - neighbour.position.pos
      
      if delta:len() > boid.tooFar then
        steer = steer + delta:normalized()
      elseif delta:len() < boid.tooClose then
        steer = steer - delta:normalized()
      end
    end
  end
  entity.input.direction = (entity.input.direction + steer):normalized()
end

CachedDrawingSystem = s{"canvas", "position"}

function CachedDrawingSystem:onDraw(entity)
  love.graphics.draw(entity.canvas, entity.position.pos)
end

ShipDrawingSystem = s{"shipLayers", "position"}

function ShipDrawingSystem:onDraw(entity, eventArgs)
  local shipLayers = entity.shipLayers
  love.graphics.setColor(1,1,1)
  
  love.graphics.push()
  love.graphics.translate(self.position.pos:unpack())
  love.graphics.draw(shipLayers.greebleSpriteBatch)
  
  love.graphics.draw(shipLayers.hullSpriteBatch)
  love.graphics.draw(shipLayers.roomChromeSpriteBatch)
  love.graphics.draw(shipLayers.wallSpriteBatch)
  love.graphics.draw(shipLayers.propSpriteBatch)
  
  love.graphics.pop()
end

return {CameraSystem, DetachSystem, AccelerationSystem, InputSystem, KeyboardInputSystem, FollowAI, LineBoid, JetpackMovement, Friction, VelocitySystem, RelativeVelocity, AttachedSystem, ColliderMover, CollisionSystem, Speeen, Fade, Triangle, RectSystem, DotSystem, MultiplySpawn, SpawnSystem, AttachOnSpawn, SpawnRelativeSystem, SpawnOnClick, SpawnRadius, RelativeStreamSpawner, StreamSpawner, LineSpawnerSystem, TimedSpawnSystem, DelayedSpawnSystem, SpawnAt, FollowMouseSystem, TimedDeathSystem, DieOnSpawn, Death, PrecisionTarget, PrecisionCenteringSystem, InteractsSystem, InteractFireEvent, DomainSystem, DomainColliderSystem, DomainTraveller, DomainEntranceSystem, DomainExitSystem, VelocityTransferSystem, DebugLogCollisions, CleanupAttached, StreamSpawnerController, require "ship_drawing".ShipDrawingSystem}