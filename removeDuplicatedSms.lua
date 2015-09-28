JSON = (loadfile "JSON.lua")() -- one-time load of the routines
local filters = JSON:decode(io.open("filters.json", "r"):read("*a"))
for i, filter in ipairs(filters) do
	filters[i].msg = filters[i].msg:lower()
end

local csv = require("csv")
local f = csv.open("sms.csv")

local list = {}
local fields = f:lines()()
for line in f:lines() do
	local l = {}
	for i, v in ipairs(line) do
		l[fields[i]] = v
	end
	l.MessageL = l.Message:lower()
	table.insert(list, l)
end

local function Log(log)
	print(log)
end

local nDuplicate, nFilter = 0, 0
local hash = {}
for i = #list, 1, -1 do
	local row = list[i]
	local hashKey = row.Date .. row.Number .. row.MessageL
	local nTime = tonumber((row.Time:gsub(":", "")))
	local bRemove
	if hash[hashKey] then
		for _, nT in ipairs(hash[hashKey]) do
			if math.abs(nT - nTime) < 500 then -- same msg in 5 min
				bRemove = true
				table.remove(list, i)
				nDuplicate = nDuplicate + 1
				Log("Duplicate: [" .. row.Date .. "][" .. row.Time .. "][" .. row.Number .. "]" .. row.Message)
				break
			end
		end
		if not bRemove then
			table.insert(hash[hashKey], nTime)
		end
	end
	if not bRemove then
		for _, filter in ipairs(filters) do
			if row.Number:find(filter.num)
			and row.Name:find(filter.name)
			and row.MessageL:find(filter.msg) then
				bRemove = true
				table.remove(list, i)
				nFilter = nFilter + 1
				Log("Filter: [" .. row.Date .. "][" .. row.Time .. "][" .. row.Number .. "]" .. row.Message)
			end
		end
		hash[hashKey] = { nTime }
	end
end
Log(("Duplicate: %d, Filter: %d."):format(nDuplicate, nFilter))

local function packageString(str)
	if str:find("[, \r\n]") then
		str = "\"" .. str:gsub('"', '""') .. "\""
	end
	return (str:gsub("\r\n", "\n"))
end

local t = {}
for _, row in ipairs(list) do
	local line = {}
	for _, key in ipairs(fields) do
		table.insert(line, packageString(row[key]))
	end
	table.insert(t, table.concat(line, ","))
end
local s = table.concat(t, "\n")

local file = io.open("sms_r.csv", "w")
file:write(s)
file:close()
