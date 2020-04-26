return function(factory)
  return function(...)
    local parent, children = factory(...)
    -- parent:resolveDependencies()
    children = children or {}
    for i = 1, #children do
      local child = children[i]
      child.attached = Attached{parent = parent, relative=child.relative}
      child.relative = nil
      --child:resolveDependencies()
    end
    return {parent, unpack(children)}
  end
end