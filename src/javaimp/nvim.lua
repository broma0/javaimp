local sys = require("santoku.system")
local err = require("santoku.err")
local str = require("santoku.string")

local M = {}
local cmp = {}

M.cmp = cmp

function cmp.new ()
  return setmetatable({}, { __index = cmp })
end

function cmp:complete (params, callback)
  local line = params.context.cursor_line
  local tok = line:sub(params.context.cursor.col - params.keyword_length, params.context.cursor.col - 1)
  local prev = line:sub(params.context.cursor.col - params.keyword_length - 1, params.context.cursor.col - params.keyword_length - 1)
  assert(err.pwrap(function (check)
    if prev == "." then
      local pos = vim.fn.getpos(".")
      vim.fn.search("\\.", "bc")
      local ivar = vim.fn.search("\\w\\+", "bc")
      local var = ivar ~= 0 and vim.fn.expand("<cword>")
      local isym = var and vim.fn.search("\\w\\+\\s\\+" .. var, "bc")
      local sym = isym and isym ~= 0 and vim.fn.expand("<cword>")
      local iline = sym and vim.fn.search("^import.*" .. sym .. ";", "bc")
      local pkg = iline and iline ~= 0 and vim.fn.getline(vim.fn.line("."))
        :match("^import%s*(.*)%.[^.]*%s*;%s*$")
      vim.fn.setpos(".", pos)
      callback(check(M.get_matches(tok, "mem", pkg, sym))
        :map(function (match)
          return {
            label = match.mem,
            detail = table.concat({ match.pkg, match.sym, match.mem }, "."),
            data = match
          }
        end)
        :unwrap())
    else
      callback(check(M.get_matches(tok, "sym"))
        :map(function (match)
          return {
            label = match.sym,
            detail = table.concat({ match.pkg, match.sym }, "."),
            data = match
          }
        end)
        :unwrap())
    end
  end))
end

function cmp:execute (item, callback)
  callback(item)
  if not item.mem then
    M.import(item.data.pkg, item.data.sym)
  end
end

M.import = function (pkg, sym)
  local import
  if sym == nil then
    import = table.concat({ "import ", pkg, ";" })
  else
    import = table.concat({ "import ", pkg, ".", sym, ";" })
  end
  local pos = vim.fn.getpos(".")
  vim.fn.cursor(0, 0)
  if 0 == vim.fn.search("^" .. import .. "$") then
    local ins = 0
    local inc = 1
    local ppos = vim.fn.search("^package")
    local ipos = vim.fn.search("^import")
    if ipos == 0 and ppos ~= 0 then
      vim.fn.append(ppos, { "", import })
      inc = inc + 1
    elseif ipos == 0 and ppos == 0 then
      vim.fn.append(0, import)
    else
      vim.fn.append(ipos - 1, import)
    end
    pos[2] = pos[2] + inc
  end
  vim.fn.setpos(".", pos)
end

M.organize_imports = function ()
  local pos = vim.fn.getpos(".")
  vim.cmd.normal("gg")
  while true do
    local ipos = vim.fn.search("^import", "cW")
    if ipos == 0 then
      break
    else
      local line = vim.fn.getline(ipos)
      local parts = str.split(line, "[ .;]")
      local sym = parts[parts.n - 1]
      vim.cmd.normal("j")
      local spos = vim.fn.search("\\(\\W\\|^\\)" .. sym .. "\\(\\W\\|$\\)", "nW")
      if spos == 0 then
        vim.cmd.normal("kdd")
      end
    end
  end
  vim.fn.setpos(".", pos)
end

M.import_token = function ()
  local sym = vim.fn.expand("<cword>")
  if sym and sym ~= "" then
    err.pwrap(function (check)
      local ms = check(M.get_matches(sym, "sym"))
      if ms.n == 1 then
        M.import(ms[1].pkg, ms[1].sym)
      elseif ms.n > 1 then
        local sym = vim.fn["fzf#run"](vim.fn["fzf#wrap"]({
          source = ms:map(function (m)
            return table.concat({ m.pkg, ".", m.sym })
          end):unwrap(),
          sink = function (sym)
            if sym and sym ~= "" then
              M.import(sym)
            else
              print("Nothing selected!")
            end
          end
        }, 1))
      else
        print("No matches!")
      end
    end, err.error)
  end
end

-- TODO: Figure out how to call javaimp directly
-- instead of via the cli. Require of sqlite/lfs
-- fails due to sybmols unable to be located
-- lua_pushsting, etc
M.get_matches = function (token, type, pkg, sym)
  local cmd = "javaimp -i ~/.javaimp.db find -t " .. type .. " "
  cmd = pkg and (cmd .. "-p " .. pkg .. " ") or cmd
  cmd = sym and (cmd .. "-s " .. sym .. " ") or cmd
  cmd = cmd .. "\"" .. token .. "\""
  return err.pwrap(function (check)
    return check(sys.sh(cmd))
      :vec():map(function (line)
        return str.split(line, "\t"):tabulate("jar", "pkg", "sym", "mem")
      end)
  end)
end

return M
