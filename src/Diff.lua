--# selene: allow(incorrect_standard_library_use, unused_variable)

-- LCS Implementation based on examples provided at
-- https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Longest_common_subsequence
local function createVector()
	local c = {}
	local mt = {
		__index = function(self, k)
			self[k] = 0
			return 0
		end
	}

	return setmetatable(c, {
		__index = function(self, k)
			self[k] = setmetatable({}, mt)

			return self[k]
		end,
	})
end

local function computeLCS(s1, s2)
	if type(s1) == "string" then s1 = s1:split("") end
	if type(s2) == "string" then s2 = s2:split("") end
	local c = createVector()
	for i = 1, #s1 + 1 do
		for j = 1, #s2 + 1 do
			if s1[i - 1] == s2[j - 1] then
				c[i][j] = c[i - 1][j - 1] + 1
			else
				c[i][j] = math.max(c[i - 1][j], c[i][j - 1])
			end
		end
	end

	return c
end

local SAME_TOKEN = ""
local INSERT_TOKEN = "+"
local REMOVE_TOKEN = "-"

local TOKEN_KEYS = "--Keys:\n"..INSERT_TOKEN.." = Insertion\n"..REMOVE_TOKEN.."= Removal\n\n"

local function getDiff(c: {{number}}, s1, s2, i: number, j: number)
	if type(s1) == "string" then s1 = s1:split("") end
	if type(s2) == "string" then s2 = s2:split("") end
	local result = {}
	if i > 0 and j > 0 and s1[i - 1] == s2[j - 1] then
		table.foreachi(getDiff(c, s1, s2, i - 1, j - 1), function(_, res)
			if not res.str then return end
			table.insert(result, {token = res.token, str = res.str})
		end)
		table.insert(result, {token = SAME_TOKEN, str = s1[i - 1]})

		return result
	end
	if j > 0 and (i == 0 or c[i][j - 1] >= c[i - 1][j]) then
		table.foreachi(getDiff(c, s1, s2, i, j - 1), function(_, res)
			if not res.str then return end
			table.insert(result, {token = res.token, str = res.str})
		end)
		table.insert(result, {token = INSERT_TOKEN, str = s2[j - 1]})		
	elseif i > 0 and (j == 0 or c[i][j - 1] < c[i - 1][j]) then
		table.foreachi(getDiff(c, s1, s2, i - 1, j), function(_, res)
			if not res.str then return end
			table.insert(result, {token = res.token, str = res.str})
		end)
		table.insert(result, {token = REMOVE_TOKEN, str = s1[i - 1]})
	end

	return result
end

local function printMultiTextDiff(s1, s2)
	s1 = s1:split("\n")
	s2 = s2:split("\n")

	local c = computeLCS(s1, s2)
	print(s1)
	print(s2)
	for _, result in pairs(getDiff(c, s1, s2, #s1 + 1, #s2 + 1)) do
		print(result.token, result.str)
	end
end

local function getMultiLineDiff(s1, s2)
	s1 = s1:split("\n")
	s2 = s2:split("\n")

	local c = computeLCS(s1, s2)
	return getDiff(c, s1, s2, #s1 + 1, #s2 + 1)
end


return {
	SAME_TOKEN = SAME_TOKEN,
	INSERT_TOKEN = INSERT_TOKEN,
	REMOVE_TOKEN = REMOVE_TOKEN,
	TOKEN_KEYS = TOKEN_KEYS,
    computeLCS = computeLCS,
    getDiff = getDiff,
    getMultiLineDiff = getMultiLineDiff
}