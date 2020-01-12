local _M = {}

local _G = _G
local upper = string.upper

local mod_path = string.match(...,".*%.") or ''

local lp = require"lpeg"
local util = require(mod_path .. 'util')
local P=lp.P
local S=lp.S
local R=lp.R
-- local B=lp.B

-- local C=lp.C
-- local Cf=lp.Cf
-- local Cc=lp.Cc



-------------------------------------------------------------------------------
------------------------- Basic Patterns
-------------------------------------------------------------------------------

-- numbers
local num_sign = (S'+-')
local digit = R'09'
local hexLit = P"0" * S"xX" * (R('09','af','AF'))^1
local octLit = P"0" * (R'07')^1
local decimals = digit^1
local exponent = S'eE' * num_sign^-1 * decimals
local floatLit = (decimals * P"." * decimals^-1  * exponent^-1) +
	(decimals * exponent) +
	( P"." * decimals * exponent^-1) + P"inf" + P"nan"
--local floatLit = (digit^1 * ((P".")^-1 * digit^0)^-1 * (S'eE' * num_sign^-1 * digit^1)^-1)
local sfloatLit = (num_sign)^-1 * floatLit
local decLit = digit^1
local sdecLit = (num_sign)^-1 * decLit

-- alphanumeric
local AZ = R('az','AZ')
local AlphaNum = AZ + R('09')
local identChar = AlphaNum + P"_"
local not_identChar = -identChar
local ident = (AZ + P"_") * (identChar)^0

-------------------------------------------------------------------------------
------------------------- Util. functions.
-------------------------------------------------------------------------------

function lines(subject)
	local _, num = subject:gsub('\n','')
	return num + 1
end

function _M.error(msg)
	return function (subject, i)
		local line = lines(subject:sub(1,i))
		_G.error('Lexical error in line '..line..', near "'
			.. util.show_text(subject:sub(i-10,i)).. '": ' .. msg, 0)
	end
end

local function literals(tab, term)
	local ret = P(false)
	for i=1,#tab do
		-- remove literal from list.
		local lit = tab[i]
		tab[i] = nil
		-- make literal pattern
		local pat = P(lit)
		-- add terminal pattern
		if term then
			pat = pat * term
		end
		-- map LITERAL -> pattern(literal)
		tab[upper(lit)] = pat
		-- combind all literals into one pattern.
		ret = pat + ret
	end
	return ret
end

-------------------------------------------------------------------------------
------------------------- Tokens
-------------------------------------------------------------------------------

_M.keywords = {
-- syntax
"syntax",
-- package
"package", "import",
-- main types
"message", "extend", "enum",
"option",
-- field modifiers
"required", "optional", "repeated",
-- message extensions
"extensions", "to", "max",
-- message groups
"group",
-- RPC
"service",
"rpc", "returns",
-- buildin types
"double", "float",
"int32", "int64",
"uint32", "uint64",
"sint32", "sint64",
"fixed32", "fixed64",
"sfixed32", "sfixed64",
"bool",
"string", "bytes",
-- booleans
"true", "false",
}
_M.KEYWORD = literals(_M.keywords, not_identChar)

_M.symbols = {
"=", ";",
".", ",",
"{", "}",
"(", ")",
"[", "]",
}
_M.SYMBOL = literals(_M.symbols)

_M.INTEGER = hexLit + octLit + decLit
_M.SINTEGER = hexLit + octLit + sdecLit
_M.NUMERIC = hexLit + octLit + floatLit + decLit
_M.SNUMERIC = hexLit + octLit + sfloatLit + sdecLit

_M.IDENTIFIER = ident

local singlequoted = P"'" * ((1 - S"'\n\r\\") + (P'\\' * 1))^0 * (P"'" + _M.error"unfinished single-quoted string")
local doublequoted = P'"' * ((1 - S'"\n\r\\') + (P'\\' * 1))^0 * (P'"' + _M.error"unfinished double-quoted string")
_M.STRING = singlequoted + doublequoted

_M.COMMENT = (P"//" * (1 - P"\n")^0) + (P"/*" * (1 - P"*/")^0 * P"*/")

-------------------------------------------------------------------------------
------------------------- Other patterns
-------------------------------------------------------------------------------

_M.SPACE = S' \t\n\r'

_M.IGNORED = (_M.SPACE + _M.COMMENT)^0

_M.TOKEN = _M.IDENTIFIER + _M.KEYWORD + _M.SYMBOL + _M.SNUMERIC + _M.STRING

_M.ANY = _M.TOKEN + _M.COMMENT + _M.SPACE

_M.BOF = P(function(s,i) return (i==1) and i end)

_M.EOF = P(-1)

return _M