local ecs = ...
local world = ecs.world
local w = world.w
local bgfx = require "bgfx"

local function create_singlton(name)
    return function (value)
        w:register {
            name = name,
            type = "lua",
        }
        w:new {
            [name] = value
        }
    end
end

local function register_tag(name)
    w:register {
        name = name,
    }
end

local s = ecs.system "luaecs_filter_system"
local ies = world:interface "ant.scene|ientity_state"

local evCreate = world:sub {"create_filter"}
local evUpdate = world:sub {"sync_filter"}

local Layer <const> = {
    primitive = {
        "foreground", "opaticy", "background", "translucent", "decal", "ui"
    },
    shadow = {
        "opaticy", "translucent"
    },
    pickup = {
        "opaticy", "translucent"
    },
    depth = {
        "opaticy"
    },
}

local function render_queue_create(e)
    local viewid = e.render_target.viewid
    local camera_eid = e.camera_eid
    local visible = e.visible
    local filter = e.primitive_filter
    local type = filter.update_type
    local mask = ies.filter_mask(filter.filter_type)
    local exclude_mask = filter.exclude_type and ies.filter_mask(filter.exclude_type) or 0

    local layer = {}
    for i, n in ipairs(Layer[type]) do
        layer[i] = n
        layer[n] = i
    end

    local mgr = w:singleton "render_queue_manager"
    mgr.tag = mgr.tag + 1
    local tagname = "render" .. "_" .. mgr.tag
    local rq = {
        tag = tagname,
        cull_tag = tagname .. "_cull",
        layer_tag = {},
        mask = mask,
        exclude_mask = exclude_mask,
        layer = layer,
        viewid = viewid,
        camera_eid = camera_eid,
        update_queue = {},
    }
    register_tag(rq.tag)
    register_tag(rq.cull_tag)
    for i = 1, #layer do
        rq.layer_tag[i] = tagname .."_"..layer[i]
        register_tag(rq.layer_tag[i])
    end
    w:new {
        [type.."_filter"] = true,
        visible = visible,
        render_queue = rq
    }
end

local function render_object_add(eid)
    local e = world[eid]
    local rc = e._rendercache
    for v in w:select "eid:in" do
        if v.eid == eid then
            v.render_object = rc
            v.render_object_update = true
            w:sync("eid render_object:out render_object_update:temp", v)
            return
        end
    end
    w:new {
        eid = eid,
        render_object = rc,
        render_object_update = true,
        filter_material = {},
    }
end

local function render_object_del(eid)
    for v in w:select "eid:in" do
        if v.eid == eid then
            w:remove(v)
            return
        end
    end
end

function s:init()
    w:register {
        name = "render_queue",
        type = "lua",
    }
    w:register {
        name = "render_object",
        type = "lua",
    }
    w:register {
        name = "eid",
        type = "int",
    }
    w:register {
        name = "filter_material",
        type = "lua",
    }
    register_tag "render_object_update"
    register_tag "visible"
    register_tag "primitive_filter"
    register_tag "pickup_filter"
    register_tag "shadow_filter"
    register_tag "depth_filter"
    create_singlton "render_queue_manager" {
        tag = 0
    }
end

function s:data_changed()
    for _, e in evCreate:unpack() do
        render_queue_create(e)
    end
end

function s:begin_filter()
    for _, eid in evUpdate:unpack() do
        local e = world[eid]
        local rc = e._rendercache
        local state = rc.entity_state
        if state == nil or rc.fx == nil then
            goto continue
        end
        local needadd = rc.vb and rc.fx and rc.state
        if needadd then
            render_object_add(eid)
        else
            render_object_del(eid)
        end
        ::continue::
    end
end

function s:end_filter()
    w:clear "render_object_update"
end

function s:render_submit()
    for v in w:select "visible render_queue:in" do
        local rq = v.render_queue
        local viewid = rq.viewid
        local camera = world[rq.camera_eid]._rendercache
        bgfx.touch(viewid)
        bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
    end
end
