-- TODO: Parallelize

local lfs = require("lfs")
local fs = require("santoku.fs")
local err = require("santoku.err")
local sys = require("santoku.system")
local gen = require("santoku.gen")
local str = require("santoku.string")
local sql = require("santoku.sqlite")
local vec = require("santoku.vector")

return function (args)

  assert(args.index, "Missing index param")
  assert(args.repo, "Missing repo param")

  local tmp

  return err.pwrap(function (check)

    local db = check(sql.open(args.index))

    -- TODO: Ensure this is cleaned up on exit,
    -- even when exception thrown, etc
    tmp = args.tmpdir or check(sys.tmpfile()) .. ".dir"

    check(db:exec([[

      pragma journal_mode=WAL;
      pragma synchronous=normal;

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
        id_pkg integer not null references pkg (id) on delete cascade,
        sym text not null,
        unique (id_pkg, sym)
      );

      create table if not exists mem (
        id integer primary key,
        id_sym integer not null references sym (id) on delete cascade,
        mem text not null,
        unique (id_sym, mem)
      );

      create index if not exists jar_jar on jar (jar);
      create index if not exists pkg_id_jar_pkg on pkg (id_jar, pkg);
      create index if not exists sym_id_pkg_sym on sym (id_pkg, sym);
      create index if not exists mem_id_sym_mem on mem (id_sym, mem);

    ]]))

    local get_jar = check(db:getter([[
      select * from jar where jar = $1
    ]]))

    local delete_jar = check(db:runner([[
      delete from jar where id = $1
    ]]))

    local add_jar = check(db:inserter([[
      insert into jar (jar, time) values ($1, $2)
    ]]))

    local get_pkg = check(db:getter([[
      select id from pkg where id_jar = $1 and pkg = $2
    ]], "id"))

    local add_pkg = check(db:inserter([[
      insert into pkg (id_jar, pkg) values ($1, $2)
    ]]))

    local get_sym = check(db:getter([[
      select id from sym where id_pkg = $1 and sym = $2
    ]], "id"))

    local add_sym = check(db:inserter([[
      insert into sym (id_pkg, sym) values ($1, $2)
    ]]))

    local get_mem = check(db:getter([[
      select id from mem where id_sym = $1 and mem = $2
    ]], "id"))

    local add_mem = check(db:inserter([[
      insert into mem (id_sym, mem) values ($1, $2)
    ]]))

    local total = 0

    fs.files(args.repo, { recurse = true })

      :map(check)
      :filter(function (fp)
        return str.endswith(fp, ".jar")
      end)

      :each(function (fp)

        check(db:begin())

        fp = check(fs.absolute(fp))
        local jar = check(get_jar(fp))
        local mod = check.exists(lfs.attributes(fp, "modification"))

        if jar and jar.time == mod then
          check(db:commit())
          return
        elseif jar then
          check(delete_jar(jar.id))
        end

        jar = check(add_jar(fp, mod))

        -- TODO: Shell quoting
        print("Processing(" .. fp .. ")")
        check(sys.sh("unzip", fp, "-d", tmp))
          :discard()

        fs.files(tmp, { recurse = true })
          :map(check)

          :map(function (file)
            if str.endswith(file, ".class") then
              return file
            else
              check(sys.rm(file))
              return
            end
          end)

          :filter()
          :chunk(1000)

          :each(function (classes)
            
            local spkg
            local ssym
            local pkg
            local sym

            -- TODO: Shell quoting
            check(sys.sh("javap -public -constants", classes:concat(" ")))
              :each(function (line)

                -- TODO: Use LPEG for this
                if not spkg then

                  spkg = line:match("^public.*class%s*([%w_%.%$]*).*{.*$")
                      or line:match("^public.*interface%s*([%w_%.%$]*).*{.*$")

                  if spkg then

                    ssym = str.split(spkg, "%.")
                    spkg = ssym:concat(".", 1, ssym.n - 1)
                    ssym = ssym[ssym.n]

                    pkg = check(get_pkg(jar, spkg))
                    if not pkg then
                      pkg = check(add_pkg(jar, spkg))
                    end

                    sym = check(get_sym(pkg, ssym))
                    if not sym then
                      sym = check(add_sym(pkg, ssym))
                    end

                  end

                else

                  local endpkg = line:match("^%s*}%s*$")

                  if not endpkg then

                    local smem = line:match("([%w_%$]*)%(")
                              or line:match("([%w_%$]*) =")
                              or line:match("([%w_%$]*);$")

                    if smem then
                      local mem = check(get_mem(sym, smem))
                      if not mem then
                        check(add_mem(sym, smem))
                        total = total + 1
                      end
                    end

                  else

                    spkg = nil
                    ssym = nil
                    pkg = nil
                    sym = nil

                  end
                end

              end)

            classes:map(sys.rm):each(check)

          end)

          check(fs.rmdirs(tmp))
          check(db:commit())
          print("Scanned(total: " .. total .. ")")

        end)

  end)

end
