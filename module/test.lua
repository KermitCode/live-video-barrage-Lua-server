-----------------------------------
----Note  :用于一些测试，不影响原程序
----Author:04007.cn
-------------------------------------

test = {}

--进入业务模块
function test.run(request)

    --阻止外部进入
    if tostring(request.author) ~= 'kermit' then
        ngx.exit(200)
    end
    
    local t =request.data
    

    --测试程序
    ngx.say('test ' .. os.date("%Y-%m-%d %H:%M:%S")  .. ':<br>')
    ngx.say('-------------------------------------------<br>')
    ngx.say(help.html(request))
    ngx.say('<br>-------------------------------------------<br>')
    ngx.say( tonumber(t))



    --danmu = ngx.shared.danmu_shm
    --local iofilter = require 'library.iofilter'

    --iofilter.badwords_check_for_update()
    --local danmus = ngx.shared.danmu_shm
    --ngx.say(help.html(danmus))
   -- ngx.exit(200);
   --


end


return test
