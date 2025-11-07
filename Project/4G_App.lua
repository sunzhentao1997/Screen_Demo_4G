function on_air724ug_send_callback(msg)
    uart_send_string3(msg)
end

function on_air724ug_recv_callback(send_cmd, recv_data)
    uart_send_string(recv_data)
    if  recv_data == nil then
        return 
    end

    if send_cmd == nil then
        return 
    end

    if string.find(send_cmd, "+SAPBR:1,1") ~= nil and string.find(recv_data, "OK") ~= nil then
        at_cops_csq()
    end

    if string.find(recv_data, '+ICCID') ~= nil then
        --**********************************************************************
        --value：            +ICCID: 卡号
        --要提取的值：       卡号
        --正则表达式：       '+ICCID: (%d*)' 
        --**********************************************************************
        local regular_e = '+ICCID: ([0-9a-zA-Z]*)'                       --正则表达式
        local my_iccid = string.match( recv_data, regular_e)             --获取的值赋给 my_iccid  
        set_text( 0, 1, 'SIM卡号：'..my_iccid)
    end

    if string.find(recv_data,"+COPS: 0,0") then
        
    end
end
