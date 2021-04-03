-- 確認 Key
table.hasKey = function (dict, key)
    for k, _ in pairs(dict) do
        if k == key then
            return true
        end
    end
    return false
end

-- 確認值
table.hasValue = function (dict, value)
    for _, v in pairs(dict) do
        if v == value then
            return true
        end
    end
    return false
end

return table
