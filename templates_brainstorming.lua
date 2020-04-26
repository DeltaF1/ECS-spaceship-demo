return Template(function (arg1)
  spaceship = {
    position = Position{pos=$arg1},
    rect = {},
    domain = {
      friction = {}
    }
  }

  children = {

  {
    relative = Position{},
    domainPortal = {domain=$parent}
    interactDomainPortal,
    collider = {radius=3}
  }

  return parent, children
end)

--
populate namepsace with arguments
make entity
pouplate namespace with "parent" = entity
generate children
add "attached" component to each child
  parent = entity
  relative = child.relative or 0
  child.relative = nil