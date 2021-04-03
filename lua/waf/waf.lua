require("libs.string")
local utime = require("utime")
local ip = require("ip")
local json = require("json")

local cur = (...):match("(.-)[^%.]+$")
local conf = require(cur .. "conf")
local redis_cluster = require("rediscluster")
local logger = require("logger")
-- 日志配罝
logger.file_path = conf.file_path
logger.file_prefix = "waf"
logger.file_date = false

local _M = {
    product = "Demo",
    host = "",
    uri = "",
    client_ip = "",
    user_agent = "",
    enable = {
        global = false,
        whitelist_ip = false,
        blacklist_ip = false,
        whitelist_domain = false,
        blacklist_uri = false,
        blacklist_user_agent = false,
        limit_frequency = false,
        limit_cc_attack = false,
    },
    rule = {
        whitelist_ip = {},
        blacklist_ip = {},
        whitelist_domain = {},
        blacklist_uri = {},
        blacklist_user_agent = {},
        limit_frequency = {},
        limit_cc_attack = {},
    },
}

function _M.new(self)
    return self
end

function _M.init(self)
    self.host = self.host:lower()
    self.uri = self.uri:lower()
    self.userAgent = self.userAgent:lower()
    
end

function _M.in_whitelist_ip(self)
    -- IP 白名單
    -- on/off
    if not self.enable.whitelist_ip then
        return false
    end
    -- check
    for _, cidr in pairs(self.rule.whitelist_ip) do
        if cidr and cidr ~= "" then
            if ip:inCIDR(cidr, self.client_ip) then
                return true
            end
        end
    end
    return false
end

function _M.in_whitelist_domain(self)
    -- 域名白名單
    -- on/off
    if not self.enable.whitelist_domain then
        return true
    end
    -- check
    for _, regex in pairs(self.rule.whitelist_domain) do
        regex = regex:gsub("%.", "%%.")
        if regex == "*" then
            return true
        end

        local noPrefix = string.format("^%s$", regex)
        if self.host:match(noPrefix) then
            return true
        end

        local prefix = string.format("^.*%%.%s$", regex)
        if self.host:match(prefix) then
            return true
        end
    end
    return false
end

function _M.in_blacklist_ip(self)
    -- IP 黑名單
    -- on/off
    if not self.enable.blacklist_ip then
        return false
    end
    -- check
    for _, cidr in pairs(self.rule.blacklist_ip) do
        if cidr and cidr ~= "" then
            if ip:inCIDR(cidr, self.client_ip) then
                return true
            end
        end
    end
    return false
end

function _M.in_blacklist_uri(self)
    -- URL 黑名單
    -- on/off
    if not self.enable.blacklist_uri then
        return false
    end
    -- check
    for _, uri in pairs(self.rule.blacklist_uri) do
        local _start, _end = self.uri:find(uri:lower())
        if _start == 1 then
            return true
        end
    end
    return false
end

function _M.in_blacklist_user_agent(self)
    -- User Agent 黑名單
    -- on/off
    if not self.enable.blacklist_user_agent then
        return false
    end
    -- check
    for _, ua in pairs(self.rule.blacklist_user_agent) do
        local _start, _end = self.user_agent:lower():find(ua:lower())
        if _start then
            return true
        end
    end
    return false
end

function _M.in_limit_frequency(self)
    -- 請求頻率限制，基於域名+URL
    -- on/off
    if not self.enable.limit_frequency then
        return false
    end
    -- percent return
    local percentBool = function(num)
        local seed = tostring(utime.getMicroSecond()):reverse():sub(5, 12)
        math.randomseed(seed)
        local rand = math.random(1, 100)
        if rand <= 100*num then
            return true
        end
        return false
    end
    -- check
    for _, r  in pairs(self.rule.limit_frequency) do
        local rule = r:split(",")
        local limitHost = rule[1]:strip()
        local limitUri = rule[2]:strip()
        local limitPerc = tonumber(rule[3]:strip())

        local checkHost, _ = self.host:find(limitHost)
        local checkUri, _ = self.uri:find(limitUri)
        if limitHost == "*" or checkHost then
            if limitUri == "*" or checkUri then
                return percentBool(limitPerc)
            end
        end
    end
    return false
end

function _M.in_limit_cc_attack(self)
    -- CC攻擊防禦，基於產品+IP+域名+URL
    -- on/off
    if not self.enable.limit_cc_attack then
        return false
    end
    -- index count action
    local limitAttack = function(index, times, duration)
        -- 共享變量，所有Worker可見
        local indexCount = string.format("%s-count", index)
        local indexTime = string.format("%s-time", index)
        local count = self.cc_record:get(indexCount)
        local time = self.cc_record:get(indexTime)
        count = tonumber(count) or 0
        time = tonumber(time) or 0
        if os.time()-time > duration then
            self.cc_record:set(indexCount, 0)
            self.cc_record:set(indexTime, os.time())
            return false
        else
            self.cc_record:set(indexCount, count+1)
        end
        if count > times then
            return true
        end
        return false
    end
    -- check
    for _, r in pairs(self.rule.limit_cc_attack) do
        local rule = r:split(",")
        local limitHost = rule[1]:strip()
        local limitUri = rule[2]:strip()
        local limitTimes = tonumber(rule[3]:strip())
        local limitDuration = tonumber(rule[4]:strip())

        local checkHost, _ = self.host:find(limitHost)
        local checkUri, _ = self.uri:find(limitUri)
        if limitHost == "*" or checkHost then
            if limitUri == "*" or checkUri then
                local index = "%s-%s-%s-%s"
                index = index:format(self.product, self.client_ip, limitHost, limitUri)
                return limitAttack(index, limitTimes, limitDuration)
            end
        end
    end
    return false
end

function _M.action(self, message)
    ngx.say(conf.waf_block_response)
end

function _M.log(self, rule, message)
    local format = {
        product = self.product,
        client_ip = self.client_ip,
        user_agent = self.user_agent,
        host = self.host,
        uri = self.uri,
        rule = rule,
        message = message,
    }
    local data = json.encode(format)
    logger:info(data)
end
    
function _M.main(self)
  
    if not self.enable.global then
        return
    end

    -- CC Atack 記錄
    if conf.waf_load_mode == "redis-cluster" then
        local redis_config = {
            name = conf.waf_redis_cluster_name,
            serv_list = conf.waf_redis_cluster_host,
            keepalive_timeout = conf.waf_redis_cluster_keepavlie_timeout,
            keepalive_cons = conf.waf_redis_cluster_keepavlie_cons,
            connection_timout = conf.waf_redis_cluster_connection_timeout,
        }
        if conf.waf_redis_cluster_auth ~= "" then
            redis_config.auth = conf.waf_redis_cluster_auth
        end
        self.cc_record = redis_cluster:new(redis_config)
    else
        self.cc_record = ngx.shared.waf_cc_record
    end

    if self:in_whitelist_ip() then
        self:log("in_whitelist_ip", string.format("%s 白名單通過", self.client_ip))
        return
    end

    if not self:in_whitelist_domain() then
        self:log("in_whitelist_domain", "非合法域名")
        self:action()
    elseif self:in_blacklist_ip() then
        self:log("in_blacklist_ip", string.format("%s 黑名單阻擋", self.client_ip))
        self:action()
    elseif self:in_blacklist_uri() then
        self:log("in_blacklist_uri", "非合法URI")
        self:action()
    elseif self:in_blacklist_user_agent() then
        self:log("in_blacklist_user_abent", "非合法UA")
        self:action()
    elseif self:in_limit_frequency() then
        self:log("in_limit_frequency", "請求頻率限制")
        self:action()
    elseif self:in_limit_cc_attack() then
        self:log("in_limit_cc_attack", "CC攻擊限制")
        self:action()
    end
end
    
return _M
