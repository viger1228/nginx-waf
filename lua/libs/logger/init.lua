local _M = {
    file_date = true,
    file_prefix = "",
    file_path = "",
}

function _M.log(self, level, content)
    local time = os.date('%Y-%m-%d %H:%M:%S')
    local message = "%sの%sの%s(line:%s)の%s"
    local stack = debug.getinfo(3)
    local short = stack.short_src
    local line = stack.currentline
    message = message:format(time, level, short, line, content)
    local date = os.date("%Y%m%d")
    local path = ""
    if self.file_path ~= "" and self.file_path:sub(-1) ~= "/" then
        self.file_path = self.file_path .. "/"
    end
    if self.file_date then
        if self.file_prefix ~= "" then
            path = "%s%s_%s.log"
        else
            path = "%s%s%s.log"
        end    
        path = path:format(self.file_path, self.file_prefix, date)
    else
        if self.file_prefix ~= "" then
            path = "%s%s.log"
            path = path:format(self.file_path, self.file_prefix)
        else
            path = "%slua.log"
            path = path:format(self.file_path)
        end    
    end
    local file = io.open(path, "a")
    file:write(message .. "\n")
    file:close()
end

function _M.info(self, content)
    self:log("INFO", content)
end

function _M.error(self, content)
    self:log("ERROR", content)
end

return _M
