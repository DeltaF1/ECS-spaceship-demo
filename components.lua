local c = require "component".makeComponentClass

-- local components = {
Position = c("position", {pos = Vector(), r = 0})
Input = c("input", {direction = Vector()})
DelayedSpawn = c("delayedSpawn", {timer = 0})
TimedDeath = c("timedDeath", {timer = 0})
TimedSpawn = c("timedSpawn", {timer = 0})
Input = c("input", {direction = Vector()})
Physics = c("physics", {vel = Vector(), accel = Vector()})
Attached = c("attached", {relative=Position{}, relativePhysics=Physics{}})
LineSpawner = c("lineSpawner", {swarm=Queue()})
-- }

-- return components