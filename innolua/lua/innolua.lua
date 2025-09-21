#! /usr/bin/env luajit

-- innolua: simple Lua module that returns a table
local M = {}

function M.Sum(a, b)
    print(string.format("Suma: %d + %d = %d", a, b, a + b))
    return a + b
end

return M
