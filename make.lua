local lm = require "luamake"
local fs = require "bee.filesystem"

local plat = (function ()
    if lm.os == "windows" then
        if lm.compiler == "gcc" then
            return "mingw"
        end
        return "msvc"
    end
    return lm.os
end)()
lm.builddir = ("build/%s/%s"):format(plat, lm.mode)
lm.bindir = ("bin/%s/%s"):format(plat, lm.mode)

local EnableEditor = true
if lm.os == "ios" then
    lm.arch = "arm64"
    lm.sys = "ios13.0"
    EnableEditor = false
end


lm.c = "c11"
lm.cxx = "c++20"
lm.msvc = {
    defines = "_CRT_SECURE_NO_WARNINGS",
    flags = {
        "-wd5105"
    }
}

if lm.mode == "release" then
    lm.msvc.ldflags = {
        "/DEBUG:FASTLINK"
    }
end

lm.ios = {
    flags = {
        "-fembed-bitcode",
        "-fobjc-arc"
    }
}

--TODO
lm.visibility = "default"

lm:import "3rd/make.lua"

local Backlist = {}
local EditorModules = {}

for path in fs.path "clibs":list_directory() do
    if fs.exists(path / "make.lua") then
        local name = path:stem():string()
        if not Backlist[name] then
            lm:import(("clibs/%s/make.lua"):format(name))
            if EnableEditor then
                EditorModules[#EditorModules + 1] = name
            end
        end
    end
end

lm:import "runtime/make.lua"

lm:phony "runtime" {
    deps = "ant"
}

if EnableEditor then
    lm:phony "editor" {
        deps = {
            "lua",
            "luac",
            EditorModules
        }
    }
    lm:default "editor"
else
    lm:default "runtime"
end
