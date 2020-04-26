Class = require "lib.inherit.composition".Class
Vector = require "vector"
require "utils"

require "love.timer"
require "love.math"

local count = 10
local elapsed = 0
local rate = ... 

local templates = require "templates"

curTime = love.timer.getTime()
while count > 0 do
  elapsed = elapsed + (love.timer.getTime() - curTime)
  if elapsed >= rate then
    love.thread.getChannel("spaceshipGen"):push(templates.Spaceship())
    elapsed = 0
    count = count - 1
  end
  curTime = love.timer.getTime()
end