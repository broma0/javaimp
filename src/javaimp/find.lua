local err = require("santoku.err")
local sql = require("santoku.sqlite")

local M = {}

M.mem = function (args)
  return err.pwrap(function (check)

    check.exists(args.index, "Missing index param")

    local db = check(sql.open(index))

    local iter = check(db:iter([[
      select distinct pkg.pkg, sym.sym, mem.mem
      from pkg, sym, mem
      where mem.id_sym = sym.id
        and sym.id_pkg = pkg.id
    ]] .. (args.pkg and [[
        and pkg.pkg = :pkg
    ]] or "") .. (args.sym and [[
        and sym.sym = :sym
    ]] or "") .. [[
        and mem.mem like :prefix || '%'
        and length(mem.mem) > 3
      order by length(mem.mem) asc
    ]] .. (args.limit and [[
      limit :limit
    ]] or "")))

    return check(iter(args))

  end)
end

M.sym = function (args)
  return err.pwrap(function (check)

    check.exists(args.index, "Missing index param")

    local db = check(sql.open(args.index))

    local iter = check(db:iter([[
      select distinct pkg.pkg, sym.sym
      from pkg, sym
      where sym.id_pkg = pkg.id
    ]] .. (args.pkg and [[
        and pkg.pkg = :pkg
    ]] or "") .. [[
        and sym.sym like :prefix || '%'
        and length(sym.sym) > 3
      order by length(sym.sym) asc
    ]] .. (args.limit and [[
      limit :limit
    ]] or "")))

    return check(iter(args))

  end)
end

return setmetatable({}, {
  __index = M,
  __call = function (_, args)
    if M[typ] then
      return M[args.typ](args)
    else
      return false, "Not a valid type"
    end
  end
})
