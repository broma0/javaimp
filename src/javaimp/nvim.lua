local sys = require("santoku.system")
local err = require("santoku.err")
local str = require("santoku.string")

local source = {}

function source.new ()
  return setmetatable({}, { __index = source })
end

-- TODO: Figure out how to call javaimp directly
-- instead of via the cli. Require of sqlite/lfs
-- fails due to sybmols unable to be located
-- lua_pushsting, etc
function source:complete (params, callback)
  local cmd = "javaimp -i ~/.javaimp.db find \""
    .. params.context.cursor_before_line:gsub("%W", "")
    .. "\""
  local ok, candidates = err.pwrap(function (check)
    return check(sys.popen(cmd))
      :vec():map(function (line)
        local parts = str.split(line, "\t")
        return { label = parts[2], pkg = parts[1] }
      end)
  end)
  callback(candidates)
end

function source:execute (item, callback)
  callback(item)
  local import = "import " .. item.pkg .. "." .. item.label .. ";"
  local pos = vim.fn.getpos(".")
  vim.fn.cursor(0, 0)
  if 0 == vim.fn.search("^" .. import .. "$") then
    vim.fn.search("^package")
    vim.fn.search("^import")
    vim.fn.append(vim.fn.line(".") - 1, import)
    pos[2] = pos[2] + 1
  end
  vim.fn.setpos(".", pos)
end

return source
