local argparse = require("argparse")
local compat = require("santoku.compat")
local err = require("santoku.err")
local find = require("javaimp.find")
local update = require("javaimp.update")

local parser = argparse()
  :name("javaimp")
  :description("A java symbol searcher and importer")

parser
  :option("-i --index", "index db")
  :count(1)

local cupdate = parser
  :command("update", "update the index")

cupdate
  :option("-d --tmpdir", "temp dir for jar unpacking")
  :count("0-1")

cupdate
  :argument("repo", "directory with jars")

local cfind = parser
  :command("find", "print the index")

cfind
  :option("-t --type", "type of symbol")
  :choices({ "sym", "mem" })
  :count(1)

cfind
  :option("-l --limit", "limit of records to return")
  :count("0-1")

cfind
  :option("-p --pkg", "package to restrict to")
  :count("0-1")

cfind
  :option("-s --sym", "symbol to restrict to (only makes sense with -t mem)")
  :count("0-1")

cfind
  :argument("prefix", "prefix to search")

local args = parser:parse()

if args.update then

  collectgarbage("stop")
  collectgarbage("collect")
  local sm = collectgarbage("count")
  local st = os.clock()

  assert(update(args))

  local et = os.clock()
  local em = collectgarbage("count")

  print("time", et - st)
  print("mem", em - sm)

elseif args.find then

  assert(err.pwrap(function (check)
    check(find(args))
      :map(check)
      :each(function (match)
        print(compat.unpack({
          match.pkg, match.sym, match.mem
        }))
      end)
    end))

end
