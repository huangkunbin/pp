local _M = {}

-- basic functions
local assert  = assert
local pairs   = pairs
local type    = type

-- imported modules
local lpeg = require 'lpeg'

-- imported functions
local P, V = lpeg.P, lpeg.V

-- escape control characters in error messages.
local escapes = {
 ['\n'] = '\\n',
 ['\r'] = '\\r',
 ['"']  = '\\"',
 ['\\'] = '\\\\',
}
for b=0,31 do
	local c = string.char(b)
	if not escapes[c] then
		escapes[c] = '\\' .. string.format('%03d', b)
	end
end



local function show_text(text)
	return text:gsub('.', escapes)
end

function _M.listOf(patt, sep)
	patt, sep = P(patt), P(sep)

	return patt * (sep * patt)^0
end

function _M.complete (dest, orig)
	for rule, patt in pairs(orig) do
		if not dest[rule] then
			dest[rule] = patt
		end
	end

	return dest
end

function _M.apply (grammar, rules, captures)
	if rules == nil then
		rules = {}
	elseif type(rules) ~= 'table' then
		rules = { rules }
	end

	_M.complete(rules, grammar)

	if type(grammar[1]) == 'string' then
		rules[1] = V(grammar[1])
	end

	if captures ~= nil then
		assert(type(captures) == 'table', 'captures must be a table')

		for rule, cap in pairs(captures) do
			if rules[rule] ~= nil then
			    rules[rule] = rules[rule] / cap
		    end
		end
	end

	return rules
end

return _M