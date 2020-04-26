return Template(
function (pos, vel)
  local width,height = love.math.random(25,35), love.math.random(20,50)
  local spaceship = {
    position = Position{pos=pos},
    physics = Physics{vel=vel},
    colour = {love.math.random(), love.math.random(), 0.5},
    rect = {width=width, height=height},
    rectangleCollider = {width=width, height=height},
    --circleCollider = {radius = 30},
    domain = {
      backup = {},
      components = {
        friction = {strength=100},
      }
    },
  }
  
  local children = {
    {
      position = Position{},
      relative = Position{pos=Vector(-5,-5)},
      colour = {0,1,0},
      rect = {width=10, height=10},
      rectangleCollider = {width=10,height=10},
      domainEntrance = {domain = spaceship},
    },
    
    {
      position = Position{},
      relative = Position{pos=Vector(-5,height-5)},
      colour = {0,1,1},
      rect = {width=10, height=10},
      rectangleCollider = {width=10,height=10},
      domainExit = {domain = spaceship},
    },
  }
  
  return spaceship, children
end
)