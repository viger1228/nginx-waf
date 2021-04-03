local cur = (...):match("(.-)[^%.]+$")
require("bit")
require(cur .. "string")

local _M = {}

function _M.inCIDR(self, cidr, ip)
    local seg =  string.split(cidr, "/")
    local cidrIP = seg[1]
    local cidrMask = tonumber(seg[2]) or 32
    -- get mask
    local mask = {0, 0, 0, 0}
    local key = 1
    local times = 0
    for num = 1, 32 do
        mask[key] = bit.lshift(mask[key], 1)
        if num <= cidrMask then
            mask[key] = mask[key] + 1
        end
        times = times + 1
        if times >= 8 then
            times = 0
            key = key + 1
        end
    end
    -- compare
    local srcIP = string.split(cidrIP, ".")
    local dstIP = string.split(ip, ".")
    for key = 1, 4 do
        if not tonumber(srcIP[key]) then
            break
        end
        if bit.band(srcIP[key], mask[key]) ~= bit.band(dstIP[key], mask[key]) then
            return false
        end
    end
    return true
end

return _M
