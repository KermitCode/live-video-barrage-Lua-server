---
-- toolkit
--

local strfind = string.find
local strgmatch = string.gmatch
local strgsub = string.gsub
local substr = string.sub
local insert = table.insert
local str_char = string.char
local type = type
local ngx = ngx
local error = error
local pairs = pairs
local io = io
local math = math
local tonumber = tonumber
local base64 = require 'base64'

local danmu = danmu


module(...)

function explode(delim, str)
	local csv_table = {}
	local cur = 1
	while 1 do
		if not str then
			break
		end
		
		local item_end = strfind(str, delim, cur)
		
		if  not item_end then
			last_item = substr(str, cur)
			if last_item then
				insert(csv_table, last_item)
			end
			break
		end
		
		item_end = item_end - 1
		
		local item = substr(str, cur, item_end)
		cur = item_end + 2
		
		insert(csv_table, item)
	end
	return csv_table
end

function fatal_error(err)
    local error_obj = {}

    if type(err) == "string" then
        error_obj.msg = err
        error_obj.code = 0

    elseif type(err) == "table" then
        error_obj = err
    end

    error(error_obj, 0)
end


function empty(var)
	return not var or var == ngx.null or var == 0 or var == false or var == ''
end


--
-- 将uid编码为更短的格式
-- 
-- @param string uid  UID
-- @return string
--
function encode_uid(uid)
	uid = strgsub(uid, "[{}%-]", "")
	local uid_bytes = ''

	for id_slice in strgmatch(uid, "[0-9a-zA-Z][0-9a-zA-Z]") do
		local sbyte = tonumber('0x' .. id_slice)
		uid_bytes = uid_bytes .. str_char(sbyte)
	end

	return base64.encode(uid_bytes)
end



--
-- 产生一个UUID
-- 
-- @return string
--
function uuid()
	local uuid_seed = ngx.var.request_uri
					.. ngx.now()
					.. math.random(0,1)
	return ngx.md5(uuid_seed)
end


--
-- 获取当前进程的UUID
--
-- @return string
--
function process_get_uuid()
	if not danmu.process.uuid then
		danmu.process.uuid = uuid()
	end

	return danmu.process.uuid
end


--
-- 检查文件是否存在 
--
-- @param string filename  文件名
-- @return boolean
--
function file_exists(filename)
	local flag = false
	local file = io.open(filename, 'r')

	if file then
		flag = true
	end
	io.close(file)

	return flag
end


--
-- 文件删除
--
-- @param string filename 文件名
-- @return boolean 状态, string 错误信息
--
function file_delete(filename)
	return os.remove(filename)
end

--
-- 读取文件内容
--
-- @param string filename	文件名
-- @return string
--
function file_get_contents(filename)
	local file = io.open(filename, 'r')
	local content = ""

	if file then
		content = file:read("*a")
		io.close(file)
	end

	return content
end


--
-- 按行读取文件内容， 并对读取到的行应用回调函数func
--
-- @param string    filename	文件名
-- @param function  fun 		回调函数。 参数为读取到的一行的内容
-- @return nil
--
function file_read_line_by_line(filename, func)
	local file = io.open(filename, 'r')

	if file then
		while 1 do
			local row = file:read("*l")

			if not row then
				break
			end

			func(row)
		end

		io.close(file)
	end
	
end


--
-- 通过指定的路径访问table
--
-- @param table src_table	源table
-- @param table paths 		访问路径(key的路径)
-- @return mixed,string
--
function access_table_by_paths(src_table, paths)
	if type(src_table) ~= "table" or type(paths) ~= "table" then
		return nil, "指定的table或路径的变量类型不正确"
	end

	local tmp_var = (function()
		return src_table
	end)()

	for idx, path_key in pairs(paths) do
		if tmp_var and tmp_var[path_key] then
			tmp_var = tmp_var[path_key]
		else
			tmp_var = nil
		end
	end

	return tmp_var
end 

