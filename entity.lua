local Entity = Class()

function Entity:resolveDependencies(component)
  if component == nil then
    for k,component in pairs(self) do
      self:resolveDependencies(v)
    end
  else
    for i = 1, #component.deps do
      local dep = component.deps[i]
      if not self[dep] then
        local class = components[dep]
        self:addComponent(class())
      end
    end
  end
end

function Entity:addComponent(component)
  self[component._name] = component
  self:resolveDependencies(component)
end

return Entity