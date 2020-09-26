-----------------------------------
--Note  :直播弹幕下行请求处理
--Author:04007.cn
-----------------------------------

down = {}

--业务模块参数有效性校验:较验后多重返回 (true/false),(request/错误提示)
function down.check(request)

    --基本处理
    if not tonumber(request.aid) or not tonumber(request.vid) or not tonumber(request.wid) or not tonumber(request.time) or not tonumber(request.endtime) then
        return false, '参数wid,vid,aid,time,endtime必须为整数'
    end
    request.aid = math.abs(math.floor(tonumber(request.aid)))
    request.vid = math.abs(math.floor(tonumber(request.vid)))
    request.wid = math.abs(math.floor(tonumber(request.wid)))
    request.time = math.floor(tonumber(request.time))
    request.endtime = math.floor(tonumber(request.endtime))

    --必须为有效整数
    if request.wid < 1 or request.vid < 1 or request.aid < 1 then
        return false, '参数wid或vid或aid无效'
    end

    --time值必须有效
    if request.time < 0 or request.endtime < 0 then
        return false, '参数time或endtime无效'
    end

    --time区间必须有效
    if request.endtime < request.time then
        return false, '结束帧值不得小于起始帧值'
    end

    --time帧区间不能超过最大值
    if request.endtime - request.time > config.max_frame_range then
        return false, '超过了最大帧区间范围:' .. config.max_frame_range
    end

    return true, request

end

--进入业务模块
function down.run(request, debug_status)

    --1,参数有效性校验
    local rs, request  = down.check(request)
    if rs == false then
        local message = tostring(request)
        ngx.log(ngx.ERR, message)
        return json.encode( help.response(nil, message, 10001))
    end

    --2，加载redis并连接连接redis
    local redis = require 'library.redis'
    local queue = redis:new()
    local ok, err = queue:connect(config.storage.queue_redis.host, config.storage.queue_redis.port)
    if not ok then
        local log_message = '连接Redis失败:' .. err
        local message = debug_status and log_message or '系统错误'
        ngx.log(ngx.ERR, log_message)
        return json.encode( help.response(nil, message, 20000))
    end

    --3,生成有序集合的key, score
    local list_key = 'dm_' .. request.wid ..'_'.. request.aid ..'_'.. request.vid
    local msgpack = require 'cmsgpack'
    local dm_data = queue:zrangebyscore(list_key, request.time, request.endtime)
    local return_table = {}
    for i,data in pairs(dm_data) do
        dm_data[i] = msgpack.unpack(data)
        for j,unit in pairs(dm_data[i]) do
            table.insert(return_table, unit)
        end
    end

    --4,释放内存放回资源进连接池、返回数据
    dm_data = nil
    queue:set_keepalive(config.storage.queue_redis.keepalive_timeout, config.storage.queue_redis.pool_size)
    return json.encode( help.response(return_table, '', 0) )

end

return down
