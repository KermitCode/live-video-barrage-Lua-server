---
-- 屏蔽词模块
--
-- 注意屏蔽词数据文件的字符集需要为 UTF-8
-- 数据文件格式为每行一个屏蔽词
--

local ngx = ngx
local type = type
local pairs = pairs
local pcall = pcall
local insert = table.insert
local byte = string.byte
local strtolower = string.lower
local strgsub = string.gsub
local strgmatch = string.gmatch
local concat = table.concat
local base_path = base_path
local utf8 = require 'library.utf8simple'
-- 繁体到简体的转换
-- local zht2zhs_table = require 'lib.sim_charset'
local utils = require 'library.utils'

local badwords = danmu.badwords

module(...)

-- 屏蔽词数据文件
local bad_words_file = base_path .. "config/Badwords.txt"
local bad_words_version_file = bad_words_file .. ".sig"


--
-- 检查更新的相关设置仅当lua_code_cache=on时有效， 否则将每个请求都会检查一次更新
-- 检查更新的频率（秒）
local check_interval = 120
-- 上次检查更新的时间（timestamp）
local latest_check_update_ts = nil


-- 全角字符-半角字符翻译表
local q2b_translist = {
    ["０"] = "0", ["１"] = "1", ["２"] = "2", ["３"] = "3", ["４"] = "4",
    ["５"] = "5", ["６"] = "6", ["７"] = "7", ["８"] = "8", ["９"] = "9",

    ["Ａ"] = "A", ["Ｂ"] = "B", ["Ｃ"] = "C", ["Ｄ"] = "D", ["Ｅ"] = "E", ["Ｆ"] = "F", ["Ｇ"] = "G", ["Ｈ"] = "H",
    ["Ｉ"] = "I", ["Ｊ"] = "J", ["Ｋ"] = "K", ["Ｌ"] = "L", ["Ｍ"] = "M", ["Ｎ"] = "N", ["Ｏ"] = "O", ["Ｐ"] = "P",
    ["Ｑ"] = "Q", ["Ｒ"] = "R", ["Ｓ"] = "S", ["Ｔ"] = "T", ["Ｕ"] = "U", ["Ｖ"] = "V", ["Ｗ"] = "W", ["Ｘ"] = "X",
    ["Ｙ"] = "Y", ["Ｚ"] = "Z", ["ａ"] = "a", ["ｂ"] = "b", ["ｃ"] = "c", ["ｄ"] = "d", ["ｅ"] = "e", ["ｆ"] = "f",
    ["ｇ"] = "g", ["ｈ"] = "h", ["ｉ"] = "i", ["ｊ"] = "j", ["ｋ"] = "k", ["ｌ"] = "l", ["ｍ"] = "m", ["ｎ"] = "n",
    ["ｏ"] = "o", ["ｐ"] = "p", ["ｑ"] = "q", ["ｒ"] = "r", ["ｓ"] = "s", ["ｔ"] = "t", ["ｕ"] = "u", ["ｖ"] = "v",
    ["ｗ"] = "w", ["ｘ"] = "x", ["ｙ"] = "y", ["ｚ"] = "z",

    -- 表面是一个c，其实不是，是特殊字符
    ["с"] = "c",

    ["　"] = " ",
    ["："] = ":", ["．"] = ".", ["。"] = ".", ["？"] = "?", ["，"] = ",", ["／"] = "/", ["；"] = ";",
    ["［"] = "[", ["］"] = "]", ["｜"] = "|", ["＃"] = "#", ["——"] = "-", ["、"] = "",
    ["‘"] = "'", ["“"] = "\"", ["【"] = "[", ["】"] = "]", ["е"] = "e", ["｛"] = "{", ["｝"] = "}",
    ["’"] = "\"", ["＼"] = "\\", ["～"] = "~", ["！"] = "!", ["＠"] = "@", ["￥"] = "$", ["％"] = "%",
    ["……"] = "...", ["＆"] = "&", ["×"] = "*", ["（"]  = "(", ["）"] = ")", ["＋"] = "+",
    ["＝"] = "=", ["·"] = ".", ["－"] = "-", ["ρ"] = "p", ["Ь"] = "b",

    -- 无法翻译的字符
    ["◢"] = ""
}

-- 数字字符-数字翻译表
local numeric_translist = {
    ["零"] = "0", ["〇"] = "0",

    ["壹"] = "1", ["一"] = "1", ["①"] = "1", ["⒈"] = "1", ["⑴"] = "1", ["㈠"] = "1", ["ⅰ"] = "1", ["❶"] = "1",

    ["贰"] = "2", ["二"] = "2", ["②"] = "2", ["⒉"] = "2", ["⑵"] = "2", ["㈡"] = "2", ["ⅱ"] = "2", ["❷"] = "2",

    ["叁"] = "3", ["三"] = "3", ["③"] = "3", ["⒊"] = "3", ["⑶"] = "3", ["㈢"] = "3", ["ⅲ"] = "3", ["❸"] = "3",

    ["肆"] = "4", ["四"] = "4", ["④"] = "4", ["⒋"] = "4", ["⑷"] = "4", ["㈣"] = "4", ["ⅳ"] = "4", ["❹"] = "4",

    ["伍"] = "5", ["五"] = "5", ["⑤"] = "5", ["⒌"] = "5", ["⑸"] = "5", ["㈤"] = "5", ["ⅴ"] = "5", ["❺"] = "5",

    ["陆"] = "6", ["六"] = "6", ["⑥"] = "6", ["⒍"] = "6", ["⑹"] = "6", ["㈥"] = "6", ["ⅵ"] = "6", ["❻"] = "6",

    ["柒"] = "7", ["七"] = "7", ["⑦"] = "7", ["⒎"] = "7", ["⑺"] = "7", ["㈦"] = "7", ["ⅶ"] = "7", ["❼"] = "7",

    ["捌"] = "8", ["八"] = "8", ["⑧"] = "8", ["⒏"] = "8", ["⑻"] = "8", ["㈧"] = "8", ["ⅷ"] = "8", ["❽"] = "8",

    ["玖"] = "9", ["九"] = "9", ["⑨"] = "9", ["⒐"] = "9", ["⑼"] = "9", ["㈨"] = "9", ["ⅸ"] = "9", ["❾"] = "9",

    ["拾"] = "10", ["㈩"] = "10", ["❿"] = "10", ["⑽"] = "10",

    ["⑪"] = "11", ["⑾"] = "11",

    ["⑫"] = "12", ["⑿"] = "12",

    ["⑬"] = "13", ["⒀"] = "13",

    ["⑭"] = "14", ["⒁"] = "14",

    ["⑮"] = "15", ["⒂"] = "15",

    ["⑯"] = "16", ["⒃"] = "16"

}

--
-- 将输入的字符串按照utf8编码拆分成单个字符
--
-- @param string    input_str   输入的字符串
-- @param function  func        应用于每个字符的回调, 如果这个函数返回false， 会停止对当前字符串内字符的遍历
-- @return boolean, string
function str_split_to_char_list(input_str, func)

    if not input_str then
        return false, "输入字符串为空"
    end

    if type(func) ~= 'function' then
        return false, "第二个参数不是一个有效的函数"
    end

    for idx, u8char, bidx in utf8.chars( input_str ) do
        local status, msg = func(idx, u8char, bidx)
        if status == false then
            return status, msg
        end
    end

    return true
end


--
-- 匹配字符串中的中文、字母(保持大小写)、阿拉伯数字
--
-- @param string    input_str   输入字符串
-- @param function  fun         应用于每个匹配成功的字符上的回调函数， 如果这个函数返回false， 会停止当前字符串匹配结果的遍历
-- @return boolea,string
--
function str_get_real_chars(input_str, func, ignore_alphanum)

    if not input_str then
        return false, "输入字符串为空"
    end

    if type(func) ~= 'function' then
        return false, "第二个参数不是一个有效的函数"
    end

    ignore_alphanum = ignore_alphanum or false

    -- 中文、英文字母、阿拉伯数字
    local pattern = '[\48-\57\65-\90\97-\122\228-\233][\128-\191]*'
    if ignore_alphanum then
        pattern = '[\228-\233][\128-\191]*'
    end

    local idx = 1
    for m in strgmatch(input_str, pattern) do
        local status, msg = func(idx, m)
        idx = idx + 1

        if status == false then
            return status, msg
        end
    end

    return true
end


--
-- 取得当前使用中的屏蔽词库的版本
--
-- @return string
--
function get_current_badwords_version()
    return badwords.version
end


--
-- 取得最新的屏蔽词库版本
--
-- @return string
--
function get_latest_badwords_version()
    local version = utils.file_get_contents(bad_words_version_file)
    return version
end


--
-- 向过滤词存储Table中添加新的过滤词
--
-- @param string word       屏蔽词
-- @param string prefix     屏蔽词存储中的key前缀(可用于区分不同的屏蔽词分组)
-- @return nil
--
function add_badwords(word, prefix)
    if not word or word == "" then
        return
    end

    -- 字母转换为小写
    word = strtolower(word)

    local prefix = prefix or "default"
    local word_char_table = {}
    local word_length = 0

    if not badwords.data then
        badwords.data = {}
    end

    -- 将指定的屏蔽词拆成单个字组成的table
    str_split_to_char_list(word, function(_, char, _)
        -- 全角字符转换为半角字符
        char = char_q2b(char)

        -- 尝试将数字字符转换为阿拉伯数字
        char = char_numeric(char)

        insert(word_char_table, char)
    end)

    word_length = #word_char_table

    if not word_char_table then
        return
    end

    local word_access_key = prefix .. "_" .. word_char_table[1]
    for idx, char in pairs(word_char_table) do

        local is_end = (idx == word_length) or false

        -- 首字
        if idx == 1 then

            if not badwords.data or not badwords.data[word_access_key] then
                badwords.data[word_access_key] = {}
                badwords.data[word_access_key][char] = {
                    _b_w_e = is_end
                }

            elseif is_end then
                badwords.data[word_access_key] = {
                    _b_w_e = is_end
                }
            end

        -- 非首字
        else

            local tmp_path = (function()
                if not badwords.data[word_access_key] then
                    badwords.data[word_access_key] = {}
                end

                return badwords.data[word_access_key]
            end)()


            for i=1, idx, 1 do
                if tmp_path and tmp_path[ word_char_table[i] ] then
                    tmp_path = tmp_path[ word_char_table[i] ]
                    -- tmp_path.e = is_end

                else
                    tmp_path[ word_char_table[i] ] = {
                        _b_w_e = is_end
                    }

                end
            end -- end for idx

        end -- end if idx

    end -- end for word_char_table

    -- dump.debug(badwords)
end


--
-- 更新屏蔽词库服务存储
--
-- @return nil
--
function update_badwords()
    -- 检查更新锁， 如果当前已经有个一任务在更新了， 就不再启动更新； NOTICE:   这个锁只在当前进程有效
    if badwords.lock_update then
        return
    end

    -- 创建更新锁
    badwords.lock_update = true

    utils.file_read_line_by_line(bad_words_file, function(word)
        local status, err = pcall(function()
            add_badwords(word)
        end)
    end)

    -- 解除更新锁
    badwords.lock_update = false
end


--
-- 检查当前使用的屏蔽词库的版本与最新的屏蔽词库版本是否一致
-- 如果不一致， 执行屏蔽词库的更新
--
-- @return nil
--
function badwords_check_for_update()
    local ts = ngx.time()
    if not latest_check_update_ts or (ts - latest_check_update_ts >= check_interval) then

        local current_version = get_current_badwords_version()
        local latest_version = get_latest_badwords_version()

        if current_version ~= latest_version then
            update_badwords()
        end

        latest_check_update_ts = ts
    end
end


--
-- 在指定的字符串中查找屏蔽词， 如果找到屏蔽词直接返回找到的第一个屏蔽词
-- 函数返回两个结果： 第一个为查找状态，如果输入字符串中存在屏蔽词该状态即为true， 否则为false
--                    第二个为找到的屏蔽词列表
--
-- @param string    input_str       输入字符串
-- @param string    method          匹配方式. 可选值为：first (找到第一个屏蔽词后立即返回), all (找到所有的屏蔽词). 默认为 first
-- @param string    prefix          屏蔽词库分组的前缀. 默认为 default
-- @param boolean   ignore_alphanum 是否跳过英文字母和阿拉伯数字
-- @return boolean, table
--
function search_bad_words(input_str, method, prefix, ignore_alphanum)
    local bad = false
    local words = nil

    method = method or 'first'
    prefix = prefix or "default"
    ignore_alphanum = ignore_alphanum or false

    if not input_str then
        return
    end

    if not badwords.data then
        return nil, "屏蔽词数据未初始化"
    end

    -- 将字符串中的英文字母全部转换为小写
    input_str = strtolower(input_str)


    local word_char_table = {}
    -- 遍历字符串的每个utf-8字符
    str_split_to_char_list(input_str, function (idx, u8char, bidx)

        -- 跳过空格
        if u8char == ' ' then
            return
        end

        -- 全角转半角
        u8char = char_q2b(u8char)

        -- 尝试数字转换
        u8char = char_numeric(u8char)

        -- 繁简转换
        -- sim_char = zht2zhs_table[u8char]
        -- if sim_char then
        --     u8char = sim_char
        -- end

        insert(word_char_table, u8char)
    end)


    input_str = concat(word_char_table)
    word_char_table = {}


    -- 匹配字符串中的中文、英文字母、阿拉伯数字 (当 ignore_alphanum 参数为true时， 只保留中文)
    str_get_real_chars(input_str, function(idx, char)
        word_char_table[idx] = char
    end, ignore_alphanum)


    -- 经过所有过滤后的输入字符串的字符数
    input_str_len = #word_char_table


    local break_match = false
    for idx, u8char in pairs(word_char_table) do
        if break_match then
            break
        end

        local word_access_key = prefix .. "_" .. u8char

        -- 屏蔽词table中不存在当前首字，跳过
        if badwords.data[ word_access_key ] then
            local word_paths = {}
            local ridx = 1

            -- 轮换首字构造字符单元， 查找屏蔽词table
            for pidx = idx, input_str_len, 1 do
                word_paths[ridx] = word_char_table[pidx]

                -- 根据字符单元(word_paths)访问屏蔽词table(badwords.data[word_access_key])
                -- 其中字符单元格式为如下table
                -- {"共", "产", "党"}
                local hit = utils.access_table_by_paths(badwords.data[word_access_key], word_paths)
                if hit and hit._b_w_e then
                    bad = true
                    if not words then
                        words = {}
                    end

                    -- 记录找到的屏蔽词
                    insert(words, concat(word_paths))

                    -- 如果查找方式为first， 直接跳出匹配
                    if method == 'first' then
                        break_match = true
                        break
                    end
                end

                ridx = ridx + 1
            end -- end for pidx

        end -- end if badwords.data

    end -- end for word_char_table

    return bad, words
end


--
-- 将指定字的全角字符转换为半角字符， 并将一些不可翻译字符替换为空
--
-- @param string input_char  输入字符
-- @return string
--
function char_q2b(input_char)
    return q2b_translist[ input_char ] or input_char
end


--
-- 汉字或符号类数字转换为阿拉伯数字
--
-- @param string input_char     输入字符
-- @return string
--
function char_numeric(input_char)
    return numeric_translist[ input_char ] or input_char
end


--
--  查找网址、域名
--
-- @param string input_str  输入字符串
-- @return boolean, table
--
function search_link(input_str)

    local found = false
    local links = {}

    local word_char_table = {}
    -- 遍历字符串的每个utf-8字符
    str_split_to_char_list(input_str, function (idx, u8char, bidx)

        -- 全角转半角
        u8char = char_q2b(u8char)

        -- 尝试数字转换
        u8char = char_numeric(u8char)

        word_char_table[idx] = u8char
    end)


    input_str = concat(word_char_table)

    for scheme, domain in strgmatch(input_str, '(http[s]?://)?(%w+%.%w+%.%w+)') do
        -- test
    end

    return found, links
end

