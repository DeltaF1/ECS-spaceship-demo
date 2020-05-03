return Template(
function(origin, direction, shipVelocity, avgDist, target)
  local lane = {
    position = Position{pos=origin},
    colour = {0,1,1},
    dot = {radius=2},
    spawn = function(self)
      vel = Vector(shipVelocity,0)
      return unpack(templates.Spaceship(nil, vel))
    end,
    lineSpawner = LineSpawner{
      line = {dir=direction},
      avgDist = avgDist,
      target = target,
    },
    spawnAbsolute = true,
    spawnRadius = {
      outer = 10,
      }
  }
  return lane, {}
end
)