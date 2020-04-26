function clone(value)
  if type(value) ~= "table" then
    return value
  end
  
  local t = {}
  
  for k,v in pairs(value) do
    t[k] = clone(v)
  end
  
  return setmetatable(t, getmetatable(value))
end