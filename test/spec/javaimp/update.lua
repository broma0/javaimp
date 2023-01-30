#!/bin/sh

local sys = require("santoku.system")

describe("javaimp", function ()

  describe("cli", function ()

    local _, idx = assert(sys.tmpfile())

    teardown(function ()
      assert(sys.rm(idx))
    end)

    describe("update", function ()
      it("should scan a directory for jars", function ()

        local _, out = assert(sys.lua("src/javaimp/cli.lua", "-i", idx, "update ."))

        local last = out:last()

        assert.equals(last, "Scanned 683968")

      end)
    end)

    -- describe("find", function ()
    --   it("should print matching symbols", function ()

    --     local _, out = assert(sys.lua("src/javaimp/cli.lua", "-i .javaimp.db find ''"))

    --     out:each(print)

    --   end)
    -- end)

  end)

end)
