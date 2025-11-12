-- This file is used to configure the air724ug module.
local setup_mobile_mccmnc = 
{
    ['46000'] = 'CMIOT',
    ['46001'] = 'uninet',
    ['46002'] = 'CMIOT',
    ['46003'] = 'ctnet',
    ['46005'] = 'ctnet',
    ['46006'] = 'uninet',
    ['46007'] = 'CMIOT',
    ['46009'] = 'uninet',
    ['46011'] = 'ctnet',
    ['46020'] = 'CMIOT'
} -- 移动接入点，用于设置网络接入点

local at_cmd_timer = 20
local air724ug_set_timer = 21
local air724ug_set_timeout = 4000
local air724ug_reset_timer = 22
local air724ug_reset_timeout = 100
local air724ug_io_power = 0x0409
local air724ug_io_reset = 0x040A

local at_cmd_send_callback = nil
local at_cmd_recv_callback = nil

List = {}

--[[
函数功能：设置回调函数
参数：send_cb - 发送命令回调函数
      recv_cb - 接收数据回调函数
--]]
function air724ug_set_callback(send_cb,recv_cb)
    at_cmd_send_callback = send_cb
    at_cmd_recv_callback = recv_cb
end

--[[
函数功能：初始化命令队列
参数：无
返回值：无
--]]
function List.new()
    return {
        first = 0,    -- 
        last = -1     -- 
    }
end

local cmd_list = List.new()
local cmd_current = nil

--[[
函数功能 将命令添加到列表中
参数:   list - 命令列表
        cmd - 要添加的命令
返回值: 无
--]]
function List.pushcmd(list, cmd)
    if cmd == nil then
        return
    end
    local last = cmd_list.last + 1
    cmd_list[last] = cmd
    cmd_list.last = last
end

--[[
函数功能：从列表中取出命令
参数：list - 命令列表
返回值：命令字符串
--]]
function List.popcmd(list)
    local first = cmd_list.first
    if first > cmd_list.last then
        return
    end

    local cmd = cmd_list[first]
    cmd_list[first] = nil
    cmd_list.first = first + 1
    return cmd
end

--[[
函数功能：装载AT命令
参数：send_cmd - 发送的AT命令
      recv_data - 接收的数据
      time_out - 超时时间
      retry - 重试次数
返回值：无
--]]
function at_cmd_load(send_cmd, recv_data, time_out, retry, callback)
    local cmd = {}

    cmd.send_cmd = send_cmd
    cmd.recv_data = recv_data
    cmd.time_out = time_out
    cmd.retry = retry
    cmd.callback = callback

    List.pushcmd(cmd_list, cmd)

    if cmd_current == nil then
        at_cmd_send_next()
    end
end

--[[
函数功能：清空命令队列
参数：无
返回值：无
--]]
function at_cmd_clear()
    cmd_current = nil
    cmd_list = nil
    cmd_list = {}
    cmd_list = List.new()
end

--[[
函数功能：发送AT命令
参数：无
返回值：无
--]]
function at_cmd_send()
    if cmd_current == nil then
        return
    end

    if string.len(cmd_current.send_cmd) > 1 then
        at_cmd_send_callback(cmd_current.send_cmd)
        at_cmd_send_callback('\r\n')
    end

    stop_timer(at_cmd_timer)
    start_timer(at_cmd_timer, cmd_current.time_out, 0, 1)
end

--[[
函数功能：发送下一条AT命令
参数：无
返回值：无
--]]
function at_cmd_send_next()
    cmd_current = List.popcmd(cmd_list)
    at_cmd_send()
end

--[[
函数功能：发送超时处理
参数：无
返回值：无
--]]
function at_cmd_send_timeout()
    if cmd_current == nil then
        return
    end

    if cmd_current.retry > 0 then
        cmd_current.retry = cmd_current.retry - 1
        at_cmd_send()
    else
        cmd_current = nil
        at_cmd_send_next()
    end
end

--[[
函数功能：数据接收处理
参数：data - 接收的数据
返回值：无
--]]
function at_cmd_recv_data(data)
	if cmd_current == nil then
        at_cmd_recv_callback(nil, data)
		at_cmd_send_next()
		return
    else
        at_cmd_recv_callback(cmd_current.send_cmd, data)
	end

    if cmd_current.callback ~= nil then
        cmd_current.callback(cmd_current.send_cmd, data)
        if string.find(data, '+COPS') ~= nil then
            cmd_current.callback('sim_oper', data)
        end
    end

	if string.find(data, cmd_current.recv_data) ~= nil then
		at_cmd_send_next()
	end
end

--[[
函数功能：4g模块上电启动
参数：无
返回值：无
--]]
function air724ug_setup()
    gpio_set_value(air724ug_io_power, 1)
    stop_timer(air724ug_set_timer)
    start_timer(air724ug_set_timer, air724ug_set_timeout, 0, 1)
end

--[[
函数功能：4g模块复位
参数：无
返回值：无
--]]
function air724ug_reset()
    gpio_set_value(air724ug_io_reset, 1)
    stop_timer(air724ug_reset_timer)
    start_timer(air724ug_reset_timer, air724ug_reset_timeout, 0, 1)
end

--[[
函数功能：4g模块系统初始化
参数：无
返回值：无
--]]
function air724ug_sys_init()
    gpio_set_out(air724ug_io_power)
    gpio_set_out(air724ug_io_reset)
    air724ug_setup()

    local function on_get_mccmnc_cb(send_cmd, recv_data)
--        uart_send_string(send_cmd)
        if send_cmd == 'sim_oper' then
--            uart_send_string('init success')
            local regular_e = '+COPS: %d*,%d*,"(%d*)"'                                     -- 正则表达式
            local my_mobile_mccmnc = string.match(recv_data, regular_e)                        -- 赋值给 my_mobile_mccmnc
            local my_mobile_oper = setup_mobile_mccmnc[my_mobile_mccmnc]
            at_cmd_load('AT+SAPBR=3,1,\"APN\",\"' .. my_mobile_oper .. '\"', 'OK', 3000, 3) -- 初始化设置
            at_cmd_load('AT+SAPBR=1,1', 'OK', 3000, 3)                                      -- 初始化设置
        end
    end

    at_cmd_load('AT','OK',500,1000)
    at_cmd_load('ATE0','OK',3000,1000)
    at_cmd_load('AT+ICCID', 'OK', 3000, 1000)
--    at_cmd_load('AT','OK',500,1000)
    at_cmd_load('AT+CGATT?','+CGATT: 1',3000,100)
    at_cmd_load('','OK',3000)                                                
    at_cmd_load('AT+COPS?','OK',3000,3,on_get_mccmnc_cb)
    at_cmd_load('AT+SAPBR=3,1,\"CONTYPE\",\"GPRS\"','OK',3000,3)
end

--[[
函数功能：4g模块复位初始化
参数：无
返回值：无
--]]
function air724ug_reset_init()
    local function on_get_mccmnc_cb(send_cmd, recv_data)
        if send_cmd == 'sim_oper' then
            local regular_e = '+COPS: %d*,%d*,"(%d*)"'                                     -- 正则表达式
            local my_mobile_mccmnc = string.match(recv_data, regular_e)                        -- 赋值给 my_mobile_mccmnc
            local my_mobile_oper = setup_mobile_mccmnc[my_mobile_mccmnc]
            at_cmd_load('AT+SAPBR=3,1,\"APN\",\"' .. my_mobile_oper .. '\"', 'OK', 3000, 3) -- 初始化设置
            at_cmd_load('AT+SAPBR=1,1', 'OK', 3000, 3)                                      -- 初始化设置
        end
    end

    at_cmd_load('AT','OK',500,1000)
    at_cmd_load('ATE0','OK',3000,1000)
    at_cmd_load('AT+ICCID', 'OK', 3000, 1000)
--    at_cmd_load('AT','OK',500,1000)
    at_cmd_load('AT+CGATT?','+CGATT: 1',3000,100)
    at_cmd_load('','OK',3000)                                                
    at_cmd_load('AT+COPS?','OK',3000,3,on_get_mccmnc_cb)
    at_cmd_load('AT+SAPBR=3,1,\"CONTYPE\",\"GPRS\"','OK',3000,3)
end

local string_val = ''

--[[
函数功能：串口接收回调函数
参数：packet - 串口返回数据包
返回值：无
--]]
function on_air724ug_recv_data(packet)
    local len = #(packet)
    local schar = ''

    for i = 0, len do
        schar = string.char(packet[i])
        if schar ~= '\n' then
            string_val = string_val .. schar
            if string_val == '>' then
                recv_data_handle(string_val)
            end
        else
--            uart_send_string(string_val)
            recv_data_handle(string_val)
        end
    end
end

--[[
函数功能：串口接收数据处理
参数：str - 接收的数据
返回值：无
--]]
function recv_data_handle(str)
	if string.len(str) >= 0 then
		at_cmd_recv_data(str)
	end
    string_val = ''
end

--[[
函数功能：定时器超时回调函数
参数：timer_id - 定时器ID
返回值：无
--]]
function on_air724ug_timer(timer_id)
    if timer_id == at_cmd_timer then
        at_cmd_send_timeout()
    end
    if timer_id == air724ug_set_timer then
        gpio_set_value(air724ug_io_power, 0)
    end
	if timer_id == air724ug_reset_timer then
        gpio_set_value(air724ug_io_reset, 0)
		at_cmd_clear()
		air724ug_reset_init()
	end
end

--[[
函数功能：设置4G模块的波特率
参数：baudrate - 波特率
返回值：无
--]]
function at_set_baudrate(baudrate)
    at_cmd_load('AT+IPR=' .. baudrate, 'OK', 1000, 3)
end

--[[
函数功能：设置4G模块的网络注册信息 运营商和信号强度
参数：无
返回值：无
--]]
function at_cops_csq()
    at_cmd_load('AT+COPS?','OK',1000)
    at_cmd_load('AT+CSQ','OK',1000)
end

--[[
函数功能：获取SIM卡的ICCID号码
参数：无
返回值：无
--]]
function at_get_iccid()
    at_cmd_load('AT+ICCID', 'OK', 1000, 3)
end

--[[
函数功能：获取基站时间
参数：无
返回值：无
--]]
function at_get_base_station_time()
    at_cmd_load('AT+CIPGSMLOC=2,1', 'OK', 9000, 3)
end
