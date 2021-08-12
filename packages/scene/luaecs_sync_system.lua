local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

local s = ecs.system "luaecs_sync_system"

local evCreate = world:sub {"component_register", "scene_entity"}
local evUpdateEntity = world:sub {"luaecs", "update_entity"}

local function isRenderObject(e)
	local rc = e._rendercache
	return rc.entity_state and rc.fx and rc.vb and rc.fx and rc.state
end

local function isCamera(e)
	return e.camera ~= nil
end

local function findEntity(eid)
	for v in w:select "eid:in" do
		if v.eid == eid then
			return v
		end
	end
end
local function isLightmapEntity(e)
	return e.lightmap ~= nil
end

function s:init()
end

function s:luaecs_sync()
	for _, _, eid in evCreate:unpack() do
		local e = world[eid]
		local policy = {}
		local data = { eid = eid, INIT = true }
		local rc = e._rendercache
		do
			local parent
			if e.parent and world[e.parent].scene_entity then
				parent = e.parent
			end
			local aabb
			if e.mesh and e.mesh.bounding and e.mesh.bounding.aabb then
				aabb = e.mesh.bounding.aabb
			end
			data.scene = {
				srt = rc.srt,
				updir = e.updir and math3d.ref(math3d.vector(e.updir)) or nil,
				aabb = aabb,
				_self = eid,
				_parent = parent,
			}
			policy[#policy+1] = "ant.scene|scene_object"
			if e.name then
				policy[#policy+1] = "ant.general|name"
				data.name = e.name
			end
		end

		if isRenderObject(e) then
			data.render_object = rc
			data.render_object_update = true
			data.filter_material = {}
			policy[#policy+1] = "ant.scene|render_object"
		elseif isLightmapEntity(e) then
			data.lightmap = e.lightmap
			policy[#policy+1] = "ant.baker|lightmap"
		elseif isCamera(e) then
			data.camera = {
				frustum     = e.frustum,
				clip_range  = e.clip_range,
				dof         = e.dof,
				srt         = data.scene.srt,
			}
			policy[#policy+1] = "ant.camera|camera"
		end
		world:luaecs_create_entity {
			policy = policy,
			data = data
		}
	end
	for _, _, eid in evUpdateEntity:unpack() do
		local e = world[eid]
		if isRenderObject(e) then
			local v = findEntity(eid)
			if v then
				v.render_object = e._rendercache
				v.render_object_update = true
				w:sync("render_object:out render_object_update?out", v)
			end
		end
	end
end

function s:luaecs_sync_remove()
	for _, eid in world:each "removed" do
		local e = world[eid]
		if e.scene_entity then
			local v = findEntity(eid)
			if v then
				w:remove(v)
			end
		end
	end
end
