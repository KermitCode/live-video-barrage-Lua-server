# live-video-barrage-Lua-server
视频直播弹幕服务器端使用nginx+lua+redis技术架构实现的代码，其中：
addtestdata.lua脚本可以实现往redis中写入大量测试数据以供压力测试及接口调试使用。
config目录下存放redis配置等数据，
config下的Badwords为要屏蔽的一些垃圾和敏感词语，程序中用于过滤。
