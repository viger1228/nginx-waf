# Nginx Waf

[![](https://img.shields.io/badge/powered%20by-walker-brightgreen.svg?style=flat-square)](https://github.com/viger1228) 

[English](https://github.com/viger1228/nginx-waf/blob/master/README.md)、[繁體中文](https://github.com/viger1228/nginx-waf/blob/master/README.zh-tw.md)

A simple WAF(Website Application Firewall) with OpenResty Lua to filter IP, Domain, URI, or User Agent.

## Install

### Deployment Environment：

```shell
OS：Centos 7
Version：3.10.0-1160.11.1.el7.x86_64
```

### Install OpenResty：

```shell
yum install yum-utils -y
yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo
yum install openresty -y
yum install openresty-resty -y 
ln -s /usr/local/openresty/nginx/sbin/nginx /usr/local/sbin/nginx
# Start Nginx
# You should change path first, Lua needs read current path
cd /usr/local/openresty/nginx/ && nginx 
```

### Copy Nginx Waf：

```shell
git clone https://github.com/viger1228/nginx-waf.git
cp -r nginx-waf/lua /usr/local/openresty/nginx/
```

### Modify Nginx.conf：

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
    # Test
    server {
        listen 80;
        server_name _ default;
        location / {
            content_by_lua "ngx.say('200 OK')";
        }
    } 
    # etc.
}
```

### Nginx Test

```shell
nginx -s reload
curl '127.0.0.1'
# Result
200 OK
```

### WAF Init Settings

```lua
# vim lua/waf/conf/init.lua
local _M = {
    -- Product
    product = "SA",
    -- Log file path
    file_path = "logs",
    -- renew interval, in seconds
    renew_rule = 10,
    -- waf model
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
    -- response if block
    waf_block_response = "403 Forbidden",
}
```

### WAF Rule Settings (YAML model)

```yaml
# vim lua/waf/conf/rule.yaml
enable:
    # switch
    global: true
    whitelist_ip: false
    blacklist_ip: false
    whitelist_domain: false
    blacklist_uri: false
    blacklist_user_agent: false
    limit_frequency: false
    limit_cc_attack: true
rule:
    # WhiteList IP
    # pass the IP in list
    whitelist_ip:
    - '127.0.0.1'

    # BlackList IP
    blacklist_ip: 
    - '192.168.1.1'

    # WhiteList Domain:
    whitelist_domain:
    - 'baidu.com'

    # blackListUri: 
    blacklist_uri:
    - '/version'

    # blackListUserAgent
    blacklist_user_agent:
    - 'java'

    # Limit Frequency
    # format: 'domain, path, weight'
    # Ex:
    # 'baidu.com, /api, 0.1' - baidu.com/api, filter 10% request
    # '*,         /,    0.2' - all domain and all path, filter 20% request
    limit_frequency: 
    - 'baidu.com, /api, 0.4'

    # Limit CC Attack 
    # format: 'domain, path, times, interval'
    # Ex:
    # 'baidu.com, /api, 30, 5' - request baidu.com/api 30 times per 5 second
    limit_cc_attack:
    - 'baidu.com, /api, 30, 3'
```

### WAF Rule Settings(Redis model)

```shell
# Redis key list
# product: SA
# turn on/off
SA_waf_enable_global
SA_waf_enable_whitelist_ip
SA_waf_enable_blacklist_ip
SA_waf_enable_whitelist_domain
SA_waf_enable_blacklist_uri
SA_waf_enable_blacklist_user_agent
SA_waf_enable_limit_frequency
SA_waf_enable_limit_cc_attack
# rule
SA_waf_rule_whitelist_ip
SA_waf_rule_blacklist_ip
SA_waf_rule_whitelist_domain
SA_waf_rule_blacklist_uri
SA_waf_rule_blacklist_user_agent
SA_waf_rule_limit_frequency
SA_waf_rule_limit_cc_attack
```

### WAF

```
nginx -s reload
for n in $(seq 1 100); do \
   curl '127.0.0.1/api' -H 'Host: baidu.com'; \
done
```

### Log Path

```shell
tailf /usr/local/openresty/nginx/logs/waf.log
```

## License

 [MIT](https://github.com/viger1228/nginx-waf/blob/master/LICENSE) © Walker
