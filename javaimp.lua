local fs = require("santoku.fs")
local err = require("santoku.err")
local fun = require("santoku.fun")
local sys = require("santoku.system")
local gen = require("santoku.gen")
local str = require("santoku.string")
local sql = require("santoku.sqlite")

local argparse = require("argparse")

local parser = argparse()
  :name("javaimp")
  :description("A java symbol searcher and importer")

parser
  :option("-i --index", "index db")
  :count(1)

parser
  :command("update", "update the index")
  :argument("repository", "directory with jars")

parser
  :command("cat", "print the index")

-- TODO: This is pretty slow
local function update (index, repo)
  err.pwrap(function (check)
    local db = check(sql.open(index))
    check(db:exec([[
      pragma journal_mode=WAL;
      create table if not exists symbols (
        pkg text,
        sym text,
        primary key (pkg, sym)
      );
    ]]))
    local addsym = check(db:runner([[
      insert into symbols (pkg, sym) values ($1, $2)
    ]]))
    local nb = 0
    check(db:begin())
    fs.files(repo, { recurse = true })
      :map(check)
      -- TODO: Curry
      :filter(function (fp)
        return str.endswith(fp, ".jar")
      end)
      -- TODO: Curry
      :map(function (fp)
        return check(sys.popen("unzip -Z1", fp))
      end)
      :flatten()
      :filter(function (fp)
        -- TODO: Should we rather check the
        -- manifest and look for exported
        -- values?
        return str.endswith(fp, ".class")
      end)
      :map(function (fp)
        fp = fp:gsub("%.class$", "")
        fp = str.split(fp, "/")
        local pkg = table.concat(fp, ".", 1, fp.n - 1)
        local sym = fp[fp.n]
        return pkg, sym
      end)
      :each(function (pkg, sym)
        if nb > 0 and nb % 1000 == 0 then
          print("Scanned " .. nb)
        end
        addsym(pkg, sym)
        nb = nb + 1
      end)
    print("Scanned " .. nb)
    check(db:commit())
  end, err.error)
end

local function cat (index)
  err.pwrap(function (check)
    local db = check(sql.open(index))
    local syms = check(db:iter("select * from symbols"))
    syms = check(syms())
    while not syms:done() do
      local sym = check(syms())
      print(sym.pkg, sym.sym)
    end
  end, err.error)
end

local args = parser:parse()

if not args.index then

  local home = os.getenv("HOME")

  if not home then
    print("Error: HOME environment variable missing and -i not specified. Exiting.")
    os.exit(1)
  end

  args.index = fs.join(home, ".javaimp.db")

end

if args.update then
  update(args.index, args.repository)
end

if args.cat then
  cat(args.index)
end
