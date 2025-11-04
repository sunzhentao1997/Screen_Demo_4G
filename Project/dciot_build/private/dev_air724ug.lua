-- This file is used to configure the air724ug module.
local at_cmd_timer = 20
local air724ug_set_timer = 21
local air724ug_set_timeout = 4000
local air724ug_reset_timer = 22
local air724ug_reset_timeout = 100
local air724ug_io_power = 0x0409
local air724ug_io_reset = 0x040A

List = {}

function List.new()
    return {
        first = 0,
        last = -1
    }
end

local cmd_list = List.new()
local cmd_current = nil

function List.pushcmd(list, cmd)
    if cmd == nil then
        return
    end

    local last = cmd_list.last + 1
    cmd_list[last] = cmd
    cmd_list.last = last
end

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

function at_cmd_load(send_cmd, recv_data, time_out, retry)
    local cmd = {}

    cmd.send_cmd = send_cmd
    cmd.recv_data = recv_data
    cmd.time_out = time_out
    cmd.retry = retry

    List.pushcmd(cmd_list, cmd)

    if cmd_current == nil then
        at_cmd_send_next()
    end
end

function at_cmd_clear()
    cmd_current = nil
    cmd_list = nil
    cmd_list = {}
    cmd_list = List.new()
end

function at_cmd_send()
    if cmd_current == nil then
        return
    end

    if string.len(cmd_current.send_cmd) > 1 then
        uart_send_string3(cmd_current.send_cmd)
        uart_send_string3('\r\n')
    end

    stop_timer(at_cmd_timer)
    start_timer(at_cmd_timer, cmd_current.time_out, 0, 1)
end

function at_cmd_send_next()
    cmd_current = List.popcmd(cmd_list)
    at_cmd_send()
end

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

function at_cmd_recv_data(data)
	if cmd_current == nil then
		at_cmd_send_next()
		return
	end

	if string.find(data, cmd_current.recv_data) ~= nil then
		at_cmd_send_next()
	end
end

function air724ug_setup()
    gpio_set_value(air724ug_io_power, 1)
    stop_timer(air724ug_set_timer)
    start_timer(air724ug_set_timer, air724ug_set_timeout, 0, 1)
end

function air724ug_reset()
    gpio_set_value(air724ug_io_reset, 1)
    stop_timer(air724ug_reset_timer)
    start_timer(air724ug_reset_timer, air724ug_reset_timeout, 0, 1)
end

function air724ug_sys_init()
    gpio_set_out(air724ug_io_power)
    gpio_set_out(air724ug_io_reset)
    air724ug_setup()

    at_cmd_load('AT', 'OK', 1000, 20)
    at_cmd_load('ATE0', 'OK', 1000, 20)
end

function air724ug_reset_init()
	at_cmd_load('AT', 'OK', 1000, 20)
    at_cmd_load('ATE0', 'OK', 1000, 20)
end

local string_val = ''

function on_air724ug_recv_data(packet)
    local len = #(packet)
    local schar = ''

    for i = 0, len do
        schar = string.char(packet[i])
        if schar ~= '\n' then
            string_val = string_val .. schar
        else
            uart_send_string(string_val)
            recv_data_handle(string_val)
        end
    end
end

function recv_data_handle(str)
	if string.len(str) >= 0 then
		at_cmd_recv_data(str)
	end
    string_val = ''
end

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
