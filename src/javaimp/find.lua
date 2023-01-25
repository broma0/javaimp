local err = require("santoku.err")
local sql = require("santoku.sqlite")

return function (index, prefix)
  return err.pwrap(function (check)
    local db = check(sql.open(index))
    local iter = check(db:iter([[
      select pkg.pkg, sym.sym
      from jar, pkg, sym
      where sym.id_pkg = pkg.id
        and sym.id_jar = jar.id
        and pkg.id_jar = jar.id
        and sym.sym like $1 || '%'
        and length(sym.sym) > 3
      order by length(sym.sym) asc
    ]]))
    return check(iter(prefix))
  end)
end
