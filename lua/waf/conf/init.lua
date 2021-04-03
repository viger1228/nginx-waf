local _M = {
    -- 產品
    product = "SA",
    -- 日志目錄
    file_path = "logs",
    -- 規則更新時間，秒
    renew_rule = 10,
    -- 規則來源
    waf_load_mode = "yaml",
    -- mode: yaml
    waf_yaml_file = "lua/waf/conf/rule.yaml",
    -- mode: redis
    waf_redis_host = "192.168.1.15",
    waf_redis_port = 6379,
    waf_redis_auth = "",
    -- mode: redis-cluster
    waf_redis_cluster_name = "waf_redis_cluster",
    waf_redis_cluster_host = {
        { ip = "192.168.1.15", port = 9001 },
        { ip = "192.168.1.15", port = 9002 },
        { ip = "192.168.1.15", port = 9003 },
    },
    waf_redis_cluster_keepavlie_timeout = 60*1000,
    waf_redis_cluster_keepavlie_cons = 1*1000,
    waf_redis_cluster_connection_timeout = 1*1000,
    waf_redis_cluster_auth = "",
    -- 被牆輸出內容
    waf_block_response = "403 Forbidden",
}

return _M
