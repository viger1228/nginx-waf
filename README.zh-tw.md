# Nginx Waf

[![](https://img.shields.io/badge/powered%20by-walker-brightgreen.svg?style=flat-square)](https://github.com/viger1228) 

[English](https://github.com/viger1228/nginx-waf/blob/master/README.md) | [繁體中文](https://github.com/viger1228/nginx-waf/blob/master/README.zh-tw.md)

藉由OpenResty Lua 實現基於IP、域名、URI、User Agent 簡單WAF防護

## Install

### 環境：

```shell
系統：Centos 7
版本：3.10.0-1160.11.1.el7.x86_64
```

### OpenResty 安裝：

```shell
yum install yum-utils -y
yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo
yum install openresty -y
yum install openresty-resty -y 
ln -s /usr/local/openresty/nginx/sbin/nginx /usr/local/sbin/nginx
# 啟動 Nginx
# 需先切換到正確目錄，Lua會取當前路徑
cd /usr/local/openresty/nginx/ && nginx 
```

### Nginx Waf 安裝：

```shell
git clone https://github.com/viger1228/nginx-waf.git
cp -r nginx-waf/lua /usr/local/openresty/nginx/
```

### 修改 Nginx.conf  配罝：

```nginx
user root;
http {
    # Lua setting
    lua_code_cache          on;
    lua_package_path        "/usr/local/openresty/lualib/?.lua;";
    lua_package_cpath       "/usr/local/openresty/lualib/?.so;";
    lua_shared_dict         waf_cc_record 64m;
    lua_shared_dict         waf_config 64m;
    lua_shared_dict         redis_cluster_slot_locks 100k;
    init_by_lua_file        lua/init.lua;
    init_worker_by_lua_file lua/init_worker.lua;
    access_by_lua_file      lua/access.lua;
    # 測試
    server {
        listen 80;
        server_name _ default;
        location / {
            content_by_lua "ngx.say('200 OK')";
        }
    } 
    # 省略...
}
```

### Nginx 測試

```shell
nginx -s reload
curl '127.0.0.1'
# 結果
200 OK
```

### WAF 程序配罝

```lua
# vim lua/waf/conf/init.lua
local _M = {
    -- 產品
    product = "SA",
    -- 日誌目錄
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
```

### WAF 規則配罝 (YAML模式)

```yaml
# vim lua/waf/conf/rule.yaml
enable:
    # 各規則開關
    global: true
    whitelist_ip: false
    blacklist_ip: false
    whitelist_domain: false
    blacklist_uri: false
    blacklist_user_agent: false
    limit_frequency: false
    limit_cc_attack: true
rule:
    # whiteListIP IP白名單
    # 白名單內的IP，一律通過
    whitelist_ip:
    - '127.0.0.1'

    # blackListIP IP黑名單
    blacklist_ip: 
    - '192.168.1.1'

    # whiteListDomain 域名限制
    whitelist_domain:
    - 'baidu.com'

    # blackListUri: 請求路徑限制
    blacklist_uri:
    - '/version'

    # blackListUserAgent: UserAgent限制
    blacklist_user_agent:
    - 'java'

    # limitFrequency 請求頻率限制
    # 格式: '域名, 路徑, 比重'
    # Ex:
    # 'baidu.com, /api, 0.1' - 訪問 baidu.com/api，限制10%的請求
    # '*,         /,    0.2' - 限制20% 所有的域名，所有路徑
    limit_frequency: 
    - 'baidu.com, /api, 0.4'

    # limitCcAttack CC攻擊限制
    # 格式: '域名, 路徑, 次數, 間隔'
    # Ex:
    # 'baidu.com, /api, 30, 5' - 每5秒只能訪問 baidu.com/api 30次
    limit_cc_attack:
    - 'baidu.com, /api, 30, 3'
```

### WAF 規則配罝 (Redis模式)

```shell
# Redis key 列表
# product: SA
# 開關
SA_waf_enable_global
SA_waf_enable_whitelist_ip
SA_waf_enable_blacklist_ip
SA_waf_enable_whitelist_domain
SA_waf_enable_blacklist_uri
SA_waf_enable_blacklist_user_agent
SA_waf_enable_limit_frequency
SA_waf_enable_limit_cc_attack
# 規則列表
SA_waf_rule_whitelist_ip
SA_waf_rule_blacklist_ip
SA_waf_rule_whitelist_domain
SA_waf_rule_blacklist_uri
SA_waf_rule_blacklist_user_agent
SA_waf_rule_limit_frequency
SA_waf_rule_limit_cc_attack
```

### WAF 測試

```
nginx -s reload
for n in $(seq 1 100); do \
   curl '127.0.0.1/api' -H 'Host: baidu.com'; \
done
```

### 日志查看

```shell
tailf /usr/local/openresty/nginx/logs/waf.log
```

## License

 [MIT](https://github.com/viger1228/nginx-waf/blob/master/LICENSE) © Walker
