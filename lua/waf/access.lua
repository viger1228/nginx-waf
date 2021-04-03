local json = require("json")
local Waf = require("waf.waf")

local waf_config = ngx.shared.waf_config:get("config")
waf_config = json.decode(waf_config)

local waf = Waf:new()
-- configure
waf.host = ngx.var.host
waf.uri = ngx.var.uri
waf.client_ip = ngx.var.remote_addr
waf.user_agent = ngx.var.http_user_agent
waf.product = waf_config.product
waf.enable = waf_config.enable
waf.rule = waf_config.rule

return waf

