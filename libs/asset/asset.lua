-- luacheck: globals import

local require = import and import(...) or require

local path = require "filesystem.path"
local seri = require "serialize.util"
local vfs_fs= require "vfs.fs"

local support_list = {
	"shader",
	"mesh",
	"state",			
	"material",
	"module",
	"texture",
	"hierarchy",
	"ske",
	"ani",	
	"lk",
	"ozz",
}

-- local loaders = setmetatable({} , {
-- 	__index = function(_, ext)
-- 		error("Unsupport assetmgr type " .. ext)
-- 	end
-- })

-- for _, mname in ipairs(support_list) do	
-- 	loaders[mname] = require ("ext_" .. mname)
-- end
local loaders = {}
local function get_loader(name)	
	local loader = loaders[assert(name)]
	if loader == nil then		
		local function is_support(name)
			for _, v in ipairs(support_list) do
				if v == name then
					return true
				end
			end
			return false
		end

		if is_support(name) then
			loader = require ("ext_" .. name)
			loaders[name] = loader
		else
			error("Unsupport assetmgr type " .. name)
		end
	end
	return loader
end

local assetmgr = {}
assetmgr.__index = assetmgr

local resources = setmetatable({}, {__mode="kv"})

local cachedir = "cache"
function assetmgr.cachedir()
	return cachedir
end

local assetdir = "assets"
function assetmgr.assetdir()
	return assetdir
end

local engine_assetpath = "engine/" .. assetdir
local engine_assetbuildpath = engine_assetpath .. "/build"

local searchdirs = {
	assetdir, 
	assetdir .. "/build",
	engine_assetpath,
	engine_assetbuildpath,
}

--[[
	asset find order:
	1. try to load respath
	2. if respath include "engine/assets" sub path, try "engine/assets/build"
	3. this file should be a relative path, then try:
		3.1. try local path, include "assets", "assets/build"
		3.2. if local path not found, try "engine/assets", "engine/assets/build".

	that insure:
		if we want a file using a path like this:
			"engine/assets/depicition/bunny.mesh"
		meaning, we want an engine file, and will not load bunny.mesh file from local directory

		if we want a file without "engine/assets" sub path, then it will try to load
		from local path, if not found, then try "engine/assets" path
]]
function assetmgr.find_valid_asset_path(respath)	
	if vfs_fs.exist(respath) then
		dprint("[vfs_fs.exist(respath)]:", respath)
		return respath
	end

	local enginebuildpath, found = respath:gsub(("^/?%s"):format(engine_assetpath), engine_assetbuildpath)
	if found ~= 0 then
		if vfs_fs.exist(enginebuildpath) then
			dprint("[vfs_fs.exist(enginebuildpath)]:", enginebuildpath)
			return enginebuildpath
		end
		return nil
	end

	for _, v in ipairs(searchdirs) do
		local p = path.join(v, respath)		
		if vfs_fs.exist(p) then
			dprint("[vfs_fs.exist(p)]:", p)
			return p
		end
	end
	return nil
end

function assetmgr.find_depiction_path(p)
	local fn = assetmgr.find_valid_asset_path(p)
	if fn == nil then
		if not p:match("^/?engine/assets") then
			local np = path.join("depiction", p)
			fn = assetmgr.find_valid_asset_path(np)			
		end
	end

	if fn == nil then
		error(string.format("invalid path, %s", p))
	end

	return fn	
end

function assetmgr.load(filename, param)
  --  print("filename", filename)
	assert(type(filename) == "string")
	local res = resources[filename]
	if res == nil then
		local moudlename = path.ext(filename)
		if moudlename == nil then
			error(string.format("not found ext from file:%s", filename))
		end		
		local loader = get_loader(moudlename)
		res = loader(filename, param)
		resources[filename] = res
	end

	return res
end

function assetmgr.save(tree, filename)
	assert(type(filename) == "string")
	seri.save(filename, tree)
end

function assetmgr.has_res(filename)
	return resources[filename] ~= nil
end

return assetmgr
