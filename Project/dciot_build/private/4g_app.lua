--[[
--运营商代码   
用于设置网络接入点
COPS 命令使用
46000 中国移动 （GSM）
46001 中国联通 （GSM）
46002 中国移动 （TD-S）
46003 中国电信（CDMA）
46004 空（似乎是专门用来做测试的）
46005 中国电信 （CDMA）
46006 中国联通 （WCDMA）
46007 中国移动 （TD-S）
46008
46009 中国联通
46010 
46011 中国电信 （FDD-LTE） 这个是电信的4G网络测试信号频道
46020 中国移动 铁路专用网络,高铁动车的移动GSM_R网,调度用的
--]]
local mobile_MCCMNC = 
{   
    ['46000']='中国移动', 
    ['46001']='中国联通', 
    ['46002']='中国移动', 
    ['46003']='中国电信', 
    ['46005']='中国电信', 
    ['46006']='中国联通', 
    ['46007']='中国移动', 
    ['46009']='中国联通', 
    ['46011']='中国电信', 
    ['46020']='中国移动' , 
}

function on_air724ug_send_callback(msg)
    uart_send_string3(msg)
end

function on_air724ug_recv_callback(send_cmd, recv_data)
    uart_send_string(send_cmd)
    uart_send_string(recv_data)
    if  recv_data == nil then
        return 
    end

    if send_cmd == nil then
        return 
    end

    if string.find(send_cmd, '+SAPBR=1,1') ~= nil and string.find(recv_data, 'OK') ~= nil then
        uart_send_string("get csq")
        at_cops_csq()
    end

    if string.find(recv_data, '+ICCID') ~= nil then
        --**********************************************************************
        --recv_data            +ICCID: 卡号
        --要提取的值：       卡号
        --正则表达式：       '+ICCID: (%d*)' 
        --**********************************************************************
        local regular_e = '+ICCID: ([0-9a-zA-Z]*)'                       --正则表达式
        local my_iccid = string.match( recv_data, regular_e)             --获取的值赋给 my_iccid  
        set_text( 0, 1, 'SIM卡号：'..my_iccid)
    end

    if string.find(recv_data,'+COPS') ~= nil then
        local regular_e = '+COPS:.*,.*,"(%d*)"'                     --正则表达式
        local my_mobile_MCCMNC = string.match( recv_data, regular_e )   --获取的值赋给 my_mobile_MCCMNC 
        set_text( 0, 2, mobile_MCCMNC[my_mobile_MCCMNC] )
    end

    if string.find(recv_data, '+CSQ') ~= nil then
        local regular_e = '+CSQ: (.*),.*'                             --正则表达式
        local my_signal_strength = tonumber(string.match(recv_data,regular_e))   --获取的值赋给 my_signal_strength 
        set_text( 0, 3, my_signal_strength)
    end
end
