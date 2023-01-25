local argparse = require("argparse")
local err = require("santoku.err")
local find = require("javaimp.find")
local update = require("javaimp.update")

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
  :command("find", "print the index")
  :argument("prefix", "prefix to search")

local args = parser:parse()

if args.update then
  update(args.index, args.repository)
end

if args.find then
  err.pwrap(function (check)
    local syms = check(find(args.index, args.prefix))
    syms:map(check):each(function (sym)
      print(sym.pkg, sym.sym)
    end)
  end, err.error)
end
