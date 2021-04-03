local cur = (...):match("(.-)[^%.]+$")
local conf = require(cur .. "conf")
local yaml = require("yaml")
local json = require("json")
local redis = require("resty.redis")
local redis_cluster = require("rediscluster")
local logger = require("logger")
-- 日志配罝
logger.file_path = conf.file_path
logger.file_prefix = "waf"
logger.file_date = false

local _M = {}

function _M.load(self)
    local product = conf.product
    local waf_config = {
        product = product,
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

    if conf.waf_load_mode == "yaml" then
        -- 從Yaml文件讀取
        local file = io.open(conf.waf_yaml_file, "rb")
        local content = file:read("*a")
        file:close()
        dict = yaml.load(content)
        waf_config.enable = dict.enable
        waf_config.rule = dict.rule
    else
        local cli
        if conf.waf_load_mode == "redis" then
        -- 從redis獲取
            cli = redis:new()
            local ok, err = cli:connect(conf.waf_redis_host, conf.waf_redis_port)
            if not ok then
                logger:error("err")
                return
            end
        elseif conf.waf_load_mode == "redis-cluster" then
        -- 從redis-cluster獲取
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
            cli = redis_cluster:new(redis_config)
        end

        -- 策略開關
        for k, _ in pairs(waf_config.enable) do
            local val, err
            local key = string.format("%s_waf_enable_%s", product, k)
            val, err = cli:get(key)
            if err then
                logger.error(err)
            elseif val == "true" then
                waf_config.enable[k] = true
            end
        end
        
        -- 規則列表
        for k, _ in pairs(waf_config.rule) do
            local val, err, len
            local key = string.format("%s_waf_rule_%s", product, k)
            val, err = cli:llen(key)
            if err then
                logger.error(err)
            else
                len = val
            end
            val, err = cli:lrange(key, 0, len)
            if err then
                logger.error(err)
            else
                waf_config.rule[k] = val
            end
        end
    end
    
    waf_config = json.encode(waf_config)
    -- 保存在Ngxin變量
    ngx.shared.waf_config:set("config", waf_config)
    logger:info("加載配罝")
    logger:info(waf_config)
end

function _M.main(self)
    local ok, err
    if ngx.worker.id() == 0 then
        ok, err = ngx.timer.at(1, self.load, self)
        if not ok then
            logger:error(err)
        end
        ok, err = ngx.timer.every(conf.renew_rule, self.load, self)
        if not ok then
            logger:error(err)
        end
    end
end

return _M
