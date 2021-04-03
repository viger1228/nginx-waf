-- split the string 
function string.split(self, sep)
    local list = {}
    local pattern = string.format("([^%s]+)", sep)
    local func = function(val)
        table.insert(list, val)
    end
    string.gsub(self, pattern, func)
    return list
end

-- trim the space on both side
function string.strip(self)
    return string.match(self, '^%s*(.-)%s*$')
end
