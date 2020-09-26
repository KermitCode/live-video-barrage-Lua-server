-----------------------------------
--Note  :直播弹幕上行请求处理
--Author:04007.cn
-----------------------------------


up = {}

--业务模块参数有效性校验:较验后多重返回 (true/false),(request/错误提示)
function up.check(request)

    --1,基本处理i
    if not tonumber(request.aid) or not tonumber(request.vid) or not tonumber(request.wid) or not tonumber(request.time) or not tonumber(request.mod) or not tonumber(request.font) or not tonumber(request.color) or not tonumber(request.movieid) then
        return false, '参数wid,vid,aid,time,font,mod,color,movieid必须为整数'
    end
    request.color = math.floor(tonumber(request.color))
    request.font = tonumber(request.font)
    request.mod = tonumber(request.mod)
    request.aid = math.abs(math.floor(tonumber(request.aid)))
    request.wid = math.abs(math.floor(tonumber(request.wid)))
    request.time = math.floor(tonumber(request.time))
    request.vid = math.abs(math.floor(tonumber(request.vid)))
    request.movieid = math.abs(math.floor(tonumber(request.movieid)))

    --2,必须为有效整数
    if request.wid <1 or request.vid <1 or request.aid <1 then
        return false, '参数wid或vid或aid无效'
    end

    --3,font字体：local valid_font_types = {[1] = "大", [2] = "中", [3] = "小"
    if request.font ~= 1 and request.font ~= 2 and request.font ~= 3 then
        return false, '无效font参数'
    end

    --4,颜色检查
    if not request.color or request.color < 0 or request.color > 16777215 then
         return false, '无效color参数'
    end

    --5,mod检查
    if request.mod ~= 1 and request.mod ~= 2 and request.mod ~= 3 then
        return false, '无效mod参数'
    end

    --6,mod检查
    if request.time < 0 then
        return false, '无效time参数'
    end

    --7,用户uid检查:{2D58D7B0-A49C-907F-39AE-9C70CBEB8F3B}
    if string.len(request.uid) > 38 or not string.match(request.uid, '^{[0-9a-zA-Z%-]+}$') then
        return false, '无效uid参数'
    end

    --8,发表单条弹幕的字数不能超过上限
    request.text = ngx.unescape_uri(request.text)
    request.text = string.match(request.text,"%s*(.-)%s*$")
    local text_len = string.len(request.text)
    if text_len < 1 or text_len > config.max_words then
        return false, '弹幕内容为空或字数超过限制'
    end

    return true, request

end


--进入业务模块
function up.run(request, debug_status)

    --1,参数有效性校验
    local rs,request  = up.check(request)
    if rs == false then
        local message = tostring(request)
        ngx.log(ngx.ERR, message)
        return json.encode( help.response(nil, message, 10001))
    end

    --2,敏感词过滤
    local iofilter = require 'library.iofilter'
    local danmu = ngx.shared.danmu_shm
    iofilter.badwords_check_for_update()    --检查共享内存中是否是最新的数据
    local bad, words = iofilter.search_bad_words(request.text)
    if bad then
        local log_message = '包含敏感词:' .. table.concat(words, ",")
        ngx.log(ngx.ERR, log_message)
        return json.encode( help.response(nil, log_message, 10003))
    end

    --3,广告网址过滤
    local found, links = iofilter.search_link(request.text)
    if found then
        local log_message = '包含广告:' .. table.concat(links, ",")
        ngx.log(ngx.ERR, log_message)
        return json.encode( help.response(nil, log_message, 10004))
    end

    --4,连接redis
    local redis = require 'library.redis'
    local queue = redis:new()
    queue:set_timeout(config.storage.queue_redis.connect_timeout)
    --redis将采用主丛模式，此处调用主服务器写入
    local ok, err = queue:connect(config.storage.write_redis.host, config.storage.write_redis.port)
    if not ok then
        local log_message = '连接Redis失败:' .. err
        local message = debug_status and log_message or '系统错误'
        ngx.log(ngx.ERR, log_message)
        return json.encode( help.response(nil, message, 20000))
    end

    --5,用户发布频繁控制
    local ttlkey = string.sub(string.gsub(request.uid, '-', ''), 2, -2) .. '_' ..request.vid
    local val = queue:get(ttlkey)
    if val and tonumber(val) == 1 then
       queue:set_keepalive(config.storage.queue_redis.keepalive_timeout, config.storage.queue_redis.pool_size)
       return json.encode( help.response(nil, '请不要频繁发弹幕', 10005))
    end

    --6,根据key, score读取redis数据,在原数据上增加弹幕
    local list_key = 'dm_' .. request.wid ..'_'.. request.aid ..'_'.. request.vid
    --判断redis里是否有这个key,如果有不处理，如果没有做个标记，后面加个失效时间
    local list_exists = queue::exists(list_key)

    local list_score = math.ceil( (tonumber(request.time) / 30)) * 30
    local msgpack = require 'cmsgpack'

    local data = queue:zrangebyscore(list_key, list_score, list_score)
    if next(data) ~= nil then
        --解析原数据
        data = msgpack.unpack(data[1])
        queue:zremrangebyscore(list_key, list_score, list_score)
    end
    table.insert(data, request)

    --7，如果弹幕数量超限，则进行衰减.
    local exceed_num = #data - config.storage.max_frame_danmu
    if exceed_num == 1 then
        table.remove(data, 1)
    elseif exceed_num > 1 then
        --此步适应配置变更，当配置值由10变为5时，发布弹幕时触发将已有10条弹幕数据减至5条
        for i=1,exceed_num do
            table.remove(data, 1)
        end
    end

    --8,添加新score和值-并添加一个key控制用户发布频繁
    queue:zadd(list_key, list_score, msgpack.pack(data))
    --如果这个list_key是第一次创建，则添加过期时间
    if tonumber(list_exists) == 0 then
        queue:expire(list_exists, config.storage.expire_danmu)
    end
    queue:setex(ttlkey, config.user_danmu_interval, 1)
    queue:set_keepalive(config.storage.write_redis.keepalive_timeout, config.storage.write_redis.pool_size)
    return json.encode( help.response({}, 'ok', 0) )

end

return up
