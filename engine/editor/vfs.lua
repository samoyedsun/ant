local localvfs = {}

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"

local repo

function localvfs.realpath(pathname)
	local rp = access.realpath(repo, pathname)
	return rp:string()
end

function localvfs.list(path)
	path = path:match "^/?(.-)/?$" .. '/'
	local item = {}
	for filename in pairs(access.list_files(repo, path)) do
		local realpath = access.realpath(repo, path .. filename)
		item[filename] = not not lfs.is_directory(realpath)
	end
	return item
end

function localvfs.type(filepath)
	local rp = access.realpath(repo, filepath)
	if lfs.is_directory(rp) then
		return "dir"
	elseif lfs.is_regular_file(rp) then
		return "file"
	end
end

function localvfs.new(rootpath)
	if not lfs.is_directory(rootpath) then
		return nil, "Not a dir"
	end
	repo = {
		_root = rootpath,
	}
	access.readmount(repo)
end

localvfs.new(lfs.absolute(lfs.path(arg[0])):remove_filename())

package.loaded.vfs = localvfs
