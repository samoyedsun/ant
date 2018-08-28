--process messages
local log, pkg_dir, sb_dir = ...

function CreateMsgProcessThread(_linda, _pkg_dir, _sb_dir)
    print("create msg process thread", tostring(_pkg_dir), tostring(_sb_dir))
    linda = _linda
    pkg_dir = _pkg_dir
    sb_dir = _sb_dir

    local vfs = require "firmware.vfs"
    local vfs_repo = vfs.new(_pkg_dir, _sb_dir .. "/Documents")

    local origin_require = require
    require = function(require_path)
        print("requiring "..require_path)
        if vfs_repo then
            local file_path = string.gsub(require_path, "%.", "/")
            file_path = file_path .. ".lua"
            local file = vfs_repo:open(file_path)
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

    print("create msg processor 11")
    local msg_process = require "fw.msg_process"
    local mp = msg_process.new(linda, pkg_dir, sb_dir, vfs_repo)

    print("update msg processor")
    while true do
        mp:mainloop()
    end
end

local lanes_err
msg_process_thread, lanes_err = lanes.gen("*", CreateMsgProcessThread)(linda, pkg_dir, sb_dir)
if not msg_process_thread then
    assert(false, "lanes error: " .. lanes_err)
end