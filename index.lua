-----------------------------------
--Note  :直播弹幕请求入口
--Author:04007.cn
-----------------------------------

--全局调试开关
debug_status = false

-------------------------------------------一、全局基础加载-----------------------------------

--1.1，定义lua文件包含路径，加载基本文件
base_path = '/opt/data/danmu_live/current/'  --全局路径前缀
package.path = base_path .. '?.lua;'
config = require 'config.config'
help   = require "library.help"
json   = require 'library.json'

--1.2，参数提取,线上手动打开全局调试开关
local uri = string.gsub( string.lower(ngx.var.uri), '/' ,'')
local params = ngx.req.get_uri_args()
if tostring(params.debug_danmu_status) =='1' then
    _G.debug_status = true
end

-------------------------------------------二、请求必用参数判断-----------------------------------

--2.1，定义请求必要参数

--[弹幕上行必须参数]--------------------------
if(uri == 'up') then

    must_params = {'uid', 'movieid', 'aid', 'vid', 'wid', 'time', 'text', 'font', 'color', 'mod'}


--[弹幕下行必须参数]--------------------------
elseif(uri == 'down') then

    must_params = {'aid', 'vid', 'wid', 'time', 'endtime'}


--[不影响原程序用于测试开发]--------------------------
elseif(uri == 'test') then

    must_params = {'author'}


else
    ngx.say('invalid request!')
    ngx.exit(200)
end


--2.2执行必要参数是否存在检验
result = help.check_must_params(params, must_params)
if(result ~= nil) then
    ngx.log(ngx.ERR, result)
    local message = debug_status and result or '缺少参数'
    ngx.say( json.encode( help.response(nil, message, 10000 )))
    ngx.exit(200)
end


-------------------------------------------三、响应请求----------------------------------

--3.1，加载请求对应模块,加载验证类
local module,err = help.load_module("module."..uri)
if err then
    local log_message = '加载模块:' .. uri .. '.lua 出错:'..err
    local message = debug_status and log_message or '系统错误'
    ngx.log(ngx.ERR, log_message)
    ngx.say( json.encode( help.response(nil, message, 20000 )))
    ngx.exit(200)
end

--3.2，执行请求并返回数据:各module直接返回经过json处理后的数据（如有错误带上错误码
local response  = module.run(params, debug_status)
ngx.say( response )
