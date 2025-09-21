#! /usr/bin/env sysbench

-- Set module search path relative to this script, then require module by name
local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
package.path = script_dir .. "../../innolua/lua/?.lua;" .. package.path
local innolua = require("innolua")

function prepare()
    print("prepare")
end

function event()
    local res = innolua.Sum(1, 2)
    print(("event %d"):format(res))
end

function cleanup()
    print("cleanup")
end
