local err = require("santoku.err")
local sql = require("santoku.sqlite")

local M = {}

M.mem = function (index, vals)
  return err.pwrap(function (check)
    local db = check(sql.open(index))
    local iter = check(db:iter([[
      select jar.jar, pkg.pkg, sym.sym, mem.mem
      from jar, pkg, sym, mem
      where mem.id_sym = sym.id
        and sym.id_pkg = pkg.id
        and pkg.id_jar = jar.id
    ]] .. (vals.pkg and [[
        and pkg.pkg = :pkg
    ]] or "") .. (vals.sym and [[
        and sym.sym = :sym
    ]] or "") .. [[
        and mem.mem like :prefix || '%'
        and length(mem.mem) > 3
      order by length(mem.mem) asc
    ]]))
    return check(iter(vals))
  end)
end

M.sym = function (index, vals)
  return err.pwrap(function (check)
    local db = check(sql.open(index))
    local iter = check(db:iter([[
      select jar.jar, pkg.pkg, sym.sym
      from jar, pkg, sym
      where sym.id_pkg = pkg.id
        and pkg.id_jar = jar.id
    ]] .. (vals.pkg and [[
        and pkg.pkg = :pkg
    ]] or "") .. [[
        and sym.sym like :prefix || '%'
        and length(sym.sym) > 3
      order by length(sym.sym) asc
    ]]))
    return check(iter(vals))
  end)
end

return setmetatable({}, {
  __index = M,
  __call = function (_, index, typ, vals)
    if M[typ] then
      return M[typ](index, vals)
    else
      return false, "Not a valid type"
    end
  end
})
