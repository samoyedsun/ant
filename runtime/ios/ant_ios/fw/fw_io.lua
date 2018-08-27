--local log, pkg_dir, sand_box_dir = ...

package.path = package.path .. ";/fw/?.lua;" .. pkg_dir .. "/fw/?.lua;" .. pkg_dir .. "/?.lua;" .. "/fw/?.lua;/libs/?.lua;/?.lua;./?/?.lua;/libs/?/?.lua;"
--TODO: find a way to set this
--path for the remote script
lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
linda = lanes.linda()


--"cat" means categories for different log
--for now we have "Script" for lua script log
--and "Bgfx" for bgfx log
--"Device" for deivce msg
--project entrance
entrance = nil

origin_print = print
function sendlog(cat, ...)
    linda:send("log", {cat, os.clock(),...})
    --origin_print(cat, ...)
end

function app_log(cat, ...)

    local output_log_string = {}
    for _, v in ipairs({...}) do
        table.insert(output_log_string, tostring(v))
    end

    sendlog(cat, table.unpack(output_log_string))
end

print = function(...)
    origin_print(...)
    --print will have a priority 1
    app_log("Script", ...)
end

perror = function(...)
    origin_print("error!", ...)
    app_log("Error", ...)
end


function CreateIOThread(linda, pkg_dir, sb_dir)
    print("init client repo")
    local vfs = require "firmware.vfs"
    local io_repo = vfs.new(pkg_dir, sb_dir.."/Documents")
    ---[[
    local origin_require = require
    require = function(require_path)
        print("requiring "..require_path)
        if io_repo then
            local file_path = string.gsub(require_path, "%.", "/")
            file_path = file_path .. ".lua"
            local file = io_repo:open(file_path)
            print("search for file path", file_path)
            if file then
                local content = file:read("a")
                print("content", content)
                file:close()

                local err, result = pcall(load, content, "@"..require_path)
                if not err then
                    print("require " .. require_path .. " error: " .. result)
                    return nil
                else
                    return result()
                end
            end
        end

        print("use origin require")
        return origin_require(require_path)
    end
--]]

    print("create io")
    local client_io = require "client_io"
    local c = client_io.new("127.0.0.1", 8888, linda, pkg_dir, sb_dir, io_repo)

    print("create io finished")
    while true do
        c:mainloop(0.001)
    end
end

local lanes_err
io_thread, lanes_err = lanes.gen("*", CreateIOThread)(linda, pkg_dir, sb_dir)
if not io_thread then
    assert(false, "lanes error: ".. lanes_err)
end



--send package to io
function SendIORequest(pkg)
    linda:send("request", pkg)
end

--register io call back function
IoCommand_name = {"run", "screenshot_req"}

IoCommand_func = {}
IoCommand_func["run"] = function(value) run(value) end

local bgfx = require "bgfx"
local screenshot_cache_num = 0
IoCommand_func["screenshot_req"] = function(value)
    if entrance then
        bgfx.request_screenshot()
        screenshot_cache_num = screenshot_cache_num + 1
        print("request screenshot: " .. value[2] .. " num: " .. screenshot_cache_num)
    end
end

function RegisterIOCommand(cmd, func)
    table.insert(IoCommand_name, cmd)
    IoCommand_func[cmd] = func
    --register command in io
    linda:send("RegisterTransmit", cmd)
end

