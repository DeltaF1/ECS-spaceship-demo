return Template(
function (pos, vel, geometry)
  local width,height = love.math.random(25,35), love.math.random(20,50)
  local spaceship = {
    position = Position{pos=pos},
    physics = Physics{vel=vel},
    --collider = HC.rectangle(0,0,width,height),
    --circleCollider = {radius = 30},
    domain = {
      backup = {},
      components = {
        friction = {strength=4},
      }
    },
    jetpackMovement = {speed=200},
    input = Input{},
    shipGeometry = geometry,
    shipLayers = ShipLayerClass{},
  }
  
  -- FIXME: stinky code
  world:addEvent(spaceship, "refreshSpriteBatches")
  
  local children = {
    {
      position = Position{},
      relative = Position{pos=Vector(-5,-5)},
      colour = {0,1,0},
      rect = {width=10, height=10},
      collider = HC.rectangle(0,0,10,10),
      domainEntrance = {domain = spaceship},
    },
    
    {
      position = Position{},
      relative = Position{pos=Vector(-5,height-5)},
      colour = {0,1,1},
      rect = {width=10, height=10},
      collider = HC.rectangle(0,0,10,10),
      domainExit = {domain = spaceship},
    },
  }
  
  for i = 1, #children do
    children[i].collider.entity = children[i]
  end
  
  return spaceship, children
end
)