---
-- 全局配置
--

return {
    -- ngx_lua共享内存
    share_dict = {
        name = "danmu_shm"
    },

    -- 防止外部调用取较大范围的帧区间对服务器造成影响，设置帧最大范围
    max_frame_range = 90,   --最大可取3秒钟间的弹幕

    max_words = 60,           --弹幕内容最大字数

    user_danmu_interval = 7,  --用户发弹幕的时间间隔

    -- 弹幕存储配置
    storage = {

        --一个帧最多存放弹幕数量
        max_frame_danmu = 15,

        --直播影片弹幕的失效时间
        expire_danmu = 86400,

        --读redis服务器配置
        queue_redis = {
            host = '127.0.0.1',
            port = 6379,
            connect_timeout = 2000,
            keepalive_timeout = 60000,
            pool_size = 100
        },

        --写redis服务器配置
        write_redis = {
            host = '127.0.0.1',
            port = 6379,
            connect_timeout = 2000,
            keepalive_timeout = 60000,
            pool_size = 100
        },
    }

}
