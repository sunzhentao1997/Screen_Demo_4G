function on_air724ug_send_callback(msg)
    uart_send_string3(msg)
end

function on_air724ug_recv_callback(send_cmd, recv_data)
    if  recv_data == nil then
        return 
    end

    if send_cmd == nil then
        return 
    end

end
