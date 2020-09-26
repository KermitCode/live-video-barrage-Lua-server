--
-- 用于存储当前弹幕进程的数据
-- 仅当lua_code_cache开启时有效
--
danmu = {
	process = {
		-- 当前LVM的UUID
		uuid = nil,
	},

	-- 屏蔽词模块的全局变量
	badwords = {
		-- 屏蔽词数据版本
		version = "0",

		-- 结构化的屏蔽词数据
		data = nil,

		-- 屏蔽词更新锁
		-- 当有更新任务正在执行时， 该值为true
		lock_update = false
	}
}