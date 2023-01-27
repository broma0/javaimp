-- TODO: Extend to look inside classes for
-- methods, etc.

local fs = require("santoku.fs")
local err = require("santoku.err")
local sys = require("santoku.system")
local gen = require("santoku.gen")
local str = require("santoku.string")
local sql = require("santoku.sqlite")

return function (index, repo)

  err.pwrap(function (check)

    local db = check(sql.open(index))

    check(db:exec([[

      pragma journal_mode=WAL;

      create table if not exists jar (
        id integer primary key,
        jar text unique not null,
        time integer not null
      );

      create table if not exists pkg (
        id integer primary key,
        id_jar integer not null references jar (id) on delete cascade,
        pkg text not null,
        unique (id_jar, pkg)
      );

      create table if not exists sym (
        id integer primary key,
        id_jar integer not null references jar (id) on delete cascade,
        id_pkg integer not null references pkg (id) on delete cascade,
        sym text not null,
        unique (id_jar, id_pkg, sym)
      );

    ]]))

    local get_jar = check(db:getter([[
      select * from jar where jar = $1
    ]]))

    local delete_jar = check(db:runner([[
      delete from jar where id = $1
    ]]))

    local add_jar = check(db:getter([[
      insert into jar (jar, time) values ($1, $2)
      returning *
    ]]))

    local get_pkg = check(db:getter([[
      select * from pkg where pkg = $1
    ]]))

    local add_pkg = check(db:getter([[
      insert into pkg (id_jar, pkg) values ($1, $2)
      returning *
    ]]))

    local get_sym = check(db:getter([[
      select * from sym
      where id_jar = $1 and id_pkg = $2 and sym = $3
    ]]))

    local add_sym = check(db:getter([[
      insert into sym (id_jar, id_pkg, sym) values ($1, $2, $3)
      returning *
    ]]))

    local nb = 0
    check(db:begin())

    -- TODO: make sure this is listing absolute
    -- paths
    fs.files(repo, { recurse = true })

      :map(check)

      :filter(function (fp)
        return str.endswith(fp, ".jar")
      end)

      :map(function (fp, attr)
        local jar = check(get_jar(fp))
        if jar and jar.time == attr.modification then
          return gen.empty()
        elseif jar then
          check(delete_jar(jar.id))
        end
        jar = check(add_jar(fp, attr.modification))
        return check(sys.popen("unzip -Z1", fp)):pastel(jar)
      end)

      :flatten()

      :filter(function (_, sym)
        return str.endswith(sym, ".class")
      end)

      :map(function (jar, sym)
        sym = sym:gsub("%.class$", "")
        sym = str.split(sym, "/")
        return jar, table.concat(sym, ".", 1, sym.n - 1), sym[sym.n]
      end)

      :each(function (jar, spkg, ssym)
        local pkg = check(get_pkg(spkg))
        if not pkg then
          pkg = check(add_pkg(jar.id, spkg))
        end
        if not check(get_sym(jar.id, pkg.id, ssym)) then
          sym = check(add_sym(jar.id, pkg.id, ssym))
          if nb > 0 and nb % 10000 == 0 then
            print("Scanned " .. nb)
            check(db:commit())
            check(db:begin())
          end
          nb = nb + 1
        end
      end)

    print("Scanned " .. nb)
    check(db:commit())

  end, err.error)

end
