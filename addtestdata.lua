-----------------------------------
--Note  :弹幕添加测试数据：
--Author:04007.cn
-----------------------------------
package.path = '/opt/baofeng-data/danmu_live/current/?.lua;'
local help = require "library/help"

--随机取一段中文、定义随机取汉字函数
text = '如你所见主节点对命令的复制工作发生在返回命令回复之后因为如果每次处理命令请求都需要等待复制操作完成的话那么主节点处理命令请求的速度将极大地降低我们必须在性能和一致性之间做出权衡'
length = help.utfstrlen(text)
function get_chinese_char(num)
    local chars = ''
    for i = 1,num do
        local index = math.random(1, length)
        local start = (index-1) * 3 + 1
        chars =  chars .. text:sub(start, start + 2)
    end
    return chars
end

--连接redis
local redis = require 'library.redis'
local config = require 'config.config'
local msgpack = require 'cmsgpack'
local queue = redis:new()
queue:set_timeout(config.storage.queue_redis.connect_timeout)
local ok, err = queue:connect(config.storage.queue_redis.host, config.storage.queue_redis.port)
if not ok then
    return ngx.say(err)
end

--设10个影片，ID如下
local video_ids  = { 2300, 2301, 2302, 2303, 2304, 2305, 2306, 2307, 2308, 2309 }
ngx.say('<h2>向redis插入1000条测试数据,分布wid:13,aid:160000,vid:2300~2309随机 弹幕帧:0-3600内</h2>')
ngx.say('<h3>-------加入的前2条数据(仅作结构示例):</h3><h5 style="font-weight:normal;">')

--生成弹幕
for i =1,1000 do
    --生成随机弹幕内容
    math.randomseed(tostring(os.time() .. math.random(0, 100000)):reverse():sub(1, 6))
    local vid = video_ids[math.random(1,10)]
    local text = i .. "--" .. get_chinese_char(math.random(5,15)) .. '--'.. os.date("%Y-%m-%d %X")
    local request = {
        uid = '{2D58D7B0-A49C-907F-39AE-9C70CBEB8F3B}',
        movieid = 111111,
        aid = 160000,
        wid = 13,
        font = 2,
        color = 16711813,
        mod = 1,
        -----以下为变化值
        vid = vid,
        time = math.random(0,3600),
        text = text,
    }

    --根据key, score读取redis数据,在原数据上增加弹幕
    local list_key = 'dm_' .. request.wid ..'_'.. request.aid ..'_'.. request.vid
    --local list_score = tonumber(request.time)
    local list_score = math.ceil( (tonumber(request.time) / 30)) * 30
    local data = queue:zrangebyscore(list_key, list_score, list_score)
    if next(data) ~= nil then
        --解析数据并移除原来的数据
        data = msgpack.unpack(data[1])
        queue:zremrangebyscore(list_key, list_score, list_score)
    end
    table.insert(data, request)

    --4，如果弹幕数量超限，则进行衰减.此处写法是为适应配置值由10变为5时，将已有10条弹幕的数据逐步减至5条
    local exceed_num = #data - config.storage.max_frame_danmu
    if exceed_num == 1 then
        table.remove(data, 1)
    elseif exceed_num > 1 then
        for i=1,exceed_num do
            table.remove(data, 1)
        end
    end

    --5,删除原score及值，添加进新的score和值
    queue:zadd(list_key, list_score, msgpack.pack(data))

    --加入的前2条数据格式
    if i <=2 then
        ngx.say(help.html(request) .. '<br>' .. string.rep('-', 100) .."<br>")
    end

end
ngx.say('</h5>')


--读取统计数据：
local dm_keys = queue:keys('dm_*')
ngx.say('<h3>-------插入后当前Redis中弹幕存储量:</h3>')
local all_dm, all_frame = 0, 0
if next(dm_keys) ~= nil then
    for i,list_key in pairs(dm_keys) do
        local dm_data = queue:zrangebyscore(list_key, 0, 100000000)
        local frame_num = #dm_data
        local tempnum = 0
        for i,data in pairs(dm_data) do
            data = msgpack.unpack(data)
            tempnum = tempnum + #data
        end

        ngx.say('sortedset key:' .. list_key .. "，帧量:" ..frame_num .." ,弹幕量:" .. tempnum .."<br>" )
        all_dm = all_dm + tempnum
        all_frame = frame_num + all_frame
    end
end
ngx.say('<br><b>影片总量:'..(#dm_keys)..'，帧总量'..all_frame ..'，弹幕总量:' .. all_dm .. "</b>")
queue:set_keepalive(config.storage.queue_redis.keepalive_timeout, config.storage.queue_redis.pool_size)