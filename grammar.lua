local _M = {}

-- local upper = string.upper
local sfind = string.find

local mod_path = string.match(...,".*%.") or ''

local lp = require"lpeg"
local util = require(mod_path .. 'util')
local scanner = require(mod_path .. 'scanner')
local error = scanner.error
local P=lp.P
-- local S=lp.S
local V=lp.V
local R=lp.R
-- local B=lp.B

-- local C=lp.C
-- local Cf=lp.Cf
-- local Cc=lp.Cc


local function rfind(s, pattern, init, finish)
  init = init or #s
  finish = finish or 1
  
  for i = init, finish, -1 do
    local lfind, rfind = sfind(s, pattern, i)
    
    if lfind and rfind then
      return lfind, rfind
    end
  end
  
  return nil
end

local function eV(val)
	return (V(val) + error("expected '" .. val .. "'"))
end
local function eP(str)
	return (P(str) + error("expected '" .. str .. "'"))
end

-------------------------------------------------------------------------------
------------------------- Protocol Buffers grammer rules
-------------------------------------------------------------------------------
local S=V'IGNORED'
local listOf = util.listOf
local E=S* eV';'

local rules = {
-- initial rule
[1] = 'Proto';

IGNORED = scanner.IGNORED, -- seen as S below
EPSILON = P(true),
EOF = scanner.EOF,
BOF = scanner.BOF,
ID = scanner.IDENTIFIER,

IntLit = scanner.INTEGER,
SIntLit = scanner.SINTEGER,
NumLit = scanner.NUMERIC,
SNumLit = scanner.SNUMERIC,
StrLit = scanner.STRING,

-- identifiers
Ident = scanner.IDENTIFIER,
Name = V'Ident' * ( V'.' * V'Ident')^0,
GroupName = R'AZ' * (V'Ident')^0,
UserType = (V'.')^-1 * V'Name',

-- Top-level
Proto = (S* (V'Message' + V'Extend' + V'Enum' + V'Syntax' + V'Import' + V'Package' + V'Option' +
	V'Service' + V';'))^0 *S,

Syntax = V'SYNTAX' *S* eV'=' *S* eV'StrLit' *E,

Import = V'IMPORT' *S* eV'StrLit' *E,
Package = V'PACKAGE' *S* eV'Name' *E,

Option = V'OPTION' *S* V'OptionBody' *E,
OptionBody = eV'Name' *S* eV'=' *S* eV'Constant',

Extend = V'EXTEND' *S* eV'UserType' *S* eV'{' * V'ExtendBody' *S* eV'}',
ExtendBody = (S* (V'Group' + V'Field' + V';'))^0,

Enum = V'ENUM' *S* V'ID' *S* eV'{' * (S* (V'Option' + V'EnumField' + V';'))^0 *S* eV'}',
EnumField = V'ID' *S* eV'=' *S* eV'SIntLit' *E,

Service = V'SERVICE' *S* eV'ID' *S* eV'{' * (S* (V'Option' + V'rpc' + V';'))^0 *S* eV'}',
rpc = V'RPC' *S* eV'ID' *S* eV'(' *S* V'UserType' *S* V')' *S*
	eV'RETURNS' *S* eV'(' *S* eV'UserType' *S* eV')' *E,

Group = V'FieldRule' *S* V'GROUP' *S* eV'GroupName' *S* eV'=' *S* eV'IntLit' *S* eV'{' *
	V'MessageBody' *S* eV'}',

Message = V'MESSAGE' *S* eV'ID' *S* eV'{' * V'MessageBody' *S* eV'}',

MessageBody = (S* (V'Group' + V'Field' + V'Enum' + V'Message' + V'Extend' + V'Extensions'
	+ V'Option' + V';'))^0,

Field = V'FieldRule' *S* eV'Type' *S* eV'ID' *S* eV'=' *S* eV'IntLit' *S*
	( V'[' *S* V'FieldOptions' *S* eV']')^-1 *E,
FieldOptions = listOf(V'OptionBody', S* V',' *S),
FieldRule = (V'REQUIRED' + V'OPTIONAL' + V'REPEATED'),

Extensions = V'EXTENSIONS' *S* V'ExtensionList' *E,
ExtensionList = listOf(V'Extension', S* V',' *S),
Extension =  eV'IntLit' *S* (V'TO' *S*
	(V'IntLit' + V'MAX' + error("expected integer or 'max'")) )^-1,

Type = (V'DOUBLE' + V'FLOAT' + 
V'INT32' + V'INT64' +
V'UINT32' + V'UINT64' +
V'SINT32' + V'SINT64' +
V'FIXED32' + V'FIXED64' +
V'SFIXED32' + V'SFIXED64' +
V'BOOL' + 
V'STRING' + V'BYTES' + V'UserType'),

BoolLit = (V'TRUE' + V'FALSE'),
Constant = (V'BoolLit' + V'ID' + V'SNumLit' + V'StrLit'),

}

-- add keywords and symbols to grammar
util.complete(rules, scanner.keywords)
util.complete(rules, scanner.symbols)


local function check(input)
  local builder = P(rules)
  local result = builder:match(input)
  
  if result ~= #input + 1 then -- failure, build the error message
    local init, _ = rfind(input, '\n*', result - 1) 
    local _, finish = sfind(input, '\n*', result + 1)
    
    init = init or 0
    finish = finish or #input
    
    local line = scanner.lines(input:sub(1, result))
    local vicinity = util.show_text(input:sub(init + 1, finish))
    
    return false, 'Syntax error at line '..line..', near "'..vicinity..'"'
  end
  
  return true
end

function _M.apply(extraRules, captures)
	return util.apply(rules, extraRules, captures)
end


return _M