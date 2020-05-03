function clone(value, seen)
  local seen = seen or {}
  if type(value) ~= "table" then
    return value
  end
  
  if seen[value] then
    return seen[value]
  end
  
  local t = {}
  seen[value] = t
  for k,v in pairs(value) do
    t[k] = clone(v, seen)
  end
  
  return setmetatable(t, getmetatable(value))
end


function tprint(t, seen)
  seen = seen or {}
  if type(t) ~= "table" then
    print(tostring(t))
    return
  end
  if seen[t] then
    print("<cycle>")
    return
  end
  seen[t] = true
  for k,v in pairs(t) do
    tprint(k)
    print ":"
    tprint(v, seen)
  end
end


function lerpColour(t, a, b)
  local r = a[1] + t * (b[1] - a[1])
  local g = a[2] + t * (b[2] - a[2])
  local b = a[3] + t * (b[3] - a[3])
  
  return {r,g,b}
end