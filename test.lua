local parser = require"parser"
local cjson = require "cjson"


-- read .proto file.
local f = assert(io.open(arg[1]))
local contents = f:read("*a")
f:close()


local table = parser.parse(contents)
local json = cjson.encode(table)

print(json)