local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local rhwi = import_package 'ant.render'.hwi
local assetmgr  = import_package "ant.asset"
local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant
local iwd = world:interface "ant.render|iwidget_drawer"
local computil = world:interface "ant.render|entity"
local gizmo_sys = ecs.system "gizmo_system"
local iom = world:interface "ant.objcontroller|obj_motion"
local ies = world:interface "ant.scene|ientity_state"

local move_axis
local rotate_axis
local uniform_scale = false
local axis_cube_scale <const> = 2.5

local gizmo_scale = 1.0
local axis_len <const> = 0.2
local uniform_rot_axis_len <const> = axis_len + 0.05

local move_plane_scale <const> = 0.08
local move_plane_offset <const> = 0.04
local move_plane_hit_radius <const> = 0.22

local SELECT <const> = 0
local MOVE <const> = 1
local ROTATE <const> = 2
local SCALE <const> = 3
local DIR_X <const> = {1, 0, 0}
local DIR_Y <const> = {0, 1, 0}
local DIR_Z <const> = {0, 0, 1}
local COLOR_X = world.component "vector" {1, 0, 0, 1}
local COLOR_Y = world.component "vector" {0, 1, 0, 1}
local COLOR_Z = world.component "vector" {0, 0, 1, 1}
local COLOR_X_ALPHA = world.component "vector" {1, 0, 0, 0.5}
local COLOR_Y_ALPHA = world.component "vector" {0, 1, 0, 0.5}
local COLOR_Z_ALPHA = world.component "vector" {0, 0, 1, 0.5}
local COLOR_GRAY = world.component "vector" {0.5, 0.5, 0.5, 1}
local COLOR_GRAY_ALPHA = world.component "vector" {0.5, 0.5, 0.5, 0.5}
local HIGHTLIGHT_COLOR_ALPHA = world.component "vector" {1, 1, 0, 0.5}

local RIGHT_TOP <const> = 0
local RIGHT_BOTTOM <const> = 1
local LEFT_BOTTOM <const> = 2
local LEFT_TOP <const> = 3

local axis_plane_area
local gizmo_obj = {
	mode = SELECT,
	position = {0,0,0},
	deactive_color = COLOR_GRAY,
	highlight_color = world.component "vector" {1, 1, 0, 1},
	--move
	tx = {dir = DIR_X, color = COLOR_X},
	ty = {dir = DIR_Y, color = COLOR_Y},
	tz = {dir = DIR_Z, color = COLOR_Z},
	txy = {dir = DIR_Z, color = COLOR_Z_ALPHA, area = RIGHT_TOP},
	tyz = {dir = DIR_X, color = COLOR_X_ALPHA, area = RIGHT_TOP},
	tzx = {dir = DIR_Y, color = COLOR_Y_ALPHA, area = RIGHT_TOP},
	--rotate
	rx = {dir = DIR_X, color = COLOR_X},
	ry = {dir = DIR_Y, color = COLOR_Y},
	rz = {dir = DIR_Z, color = COLOR_Z},
	rw = {dir = DIR_Z, color = COLOR_GRAY},
	--scale
	sx = {dir = DIR_X, color = COLOR_X},
	sy = {dir = DIR_Y, color = COLOR_Y},
	sz = {dir = DIR_Z, color = COLOR_Z},
}

local function showMoveGizmo(show)
	local state = "visible"
	ies.set_state(gizmo_obj.tx.eid[1], state, show)
	ies.set_state(gizmo_obj.tx.eid[2], state, show)
	ies.set_state(gizmo_obj.ty.eid[1], state, show)
	ies.set_state(gizmo_obj.ty.eid[2], state, show)
	ies.set_state(gizmo_obj.tz.eid[1], state, show)
	ies.set_state(gizmo_obj.tz.eid[2], state, show)
	--
	ies.set_state(gizmo_obj.txy.eid[1], state, show)
	ies.set_state(gizmo_obj.tyz.eid[1], state, show)
	ies.set_state(gizmo_obj.tzx.eid[1], state, show)
end

local function showRotateGizmo(show)
	local state = "visible"
	ies.set_state(gizmo_obj.rx.eid[1], state, show)
	ies.set_state(gizmo_obj.rx.eid[2], state, show)
	ies.set_state(gizmo_obj.ry.eid[1], state, show)
	ies.set_state(gizmo_obj.ry.eid[2], state, show)
	ies.set_state(gizmo_obj.rz.eid[1], state, show)
	ies.set_state(gizmo_obj.rz.eid[2], state, show)
	ies.set_state(gizmo_obj.rw.eid[1], state, show)
end

local function showScaleGizmo(show)
	local state = "visible"
	ies.set_state(gizmo_obj.sx.eid[1], state, show)
	ies.set_state(gizmo_obj.sx.eid[2], state, show)
	ies.set_state(gizmo_obj.sy.eid[1], state, show)
	ies.set_state(gizmo_obj.sy.eid[2], state, show)
	ies.set_state(gizmo_obj.sz.eid[1], state, show)
	ies.set_state(gizmo_obj.sz.eid[2], state, show)
	ies.set_state(gizmo_obj.uniform_scale_eid, state, show)
end

local function showGizmoByState(show)
	if show and not gizmo_obj.target_eid then
		return
	end
	if gizmo_obj.mode == MOVE then
		showMoveGizmo(show)
	elseif gizmo_obj.mode == ROTATE then
		showRotateGizmo(show)
	elseif gizmo_obj.mode == SCALE then
		showScaleGizmo(show)
	else
		showMoveGizmo(false)
		showRotateGizmo(false)
		showScaleGizmo(false)
	end
end

local function onGizmoMode(mode)
	showGizmoByState(false)
	gizmo_obj.mode = mode
	showGizmoByState(true)
end

local imaterial = world:interface "ant.asset|imaterial"

local function resetMoveAxisColor()
	local uname = "u_color"
	imaterial.set_property(gizmo_obj.tx.eid[1], uname, COLOR_X)
	imaterial.set_property(gizmo_obj.tx.eid[2], uname, COLOR_X)
	imaterial.set_property(gizmo_obj.ty.eid[1], uname, COLOR_Y)
	imaterial.set_property(gizmo_obj.ty.eid[2], uname, COLOR_Y)
	imaterial.set_property(gizmo_obj.tz.eid[1], uname, COLOR_Z)
	imaterial.set_property(gizmo_obj.tz.eid[2], uname, COLOR_Z)
	--plane
	imaterial.set_property(gizmo_obj.txy.eid[1], uname, gizmo_obj.txy.color)
	imaterial.set_property(gizmo_obj.tyz.eid[1], uname, gizmo_obj.tyz.color)
	imaterial.set_property(gizmo_obj.tzx.eid[1], uname, gizmo_obj.tzx.color)
end

local function resetRotateAxisColor()
	local uname = "u_color"
	imaterial.set_property(gizmo_obj.rx.eid[1], uname, COLOR_X)
	imaterial.set_property(gizmo_obj.rx.eid[2], uname, COLOR_X)
	imaterial.set_property(gizmo_obj.ry.eid[1], uname, COLOR_Y)
	imaterial.set_property(gizmo_obj.ry.eid[2], uname, COLOR_Y)
	imaterial.set_property(gizmo_obj.rz.eid[1], uname, COLOR_Z)
	imaterial.set_property(gizmo_obj.rz.eid[2], uname, COLOR_Z)
	imaterial.set_property(gizmo_obj.rw.eid[1], uname, COLOR_GRAY)
end

local function resetScaleAxisColor()
	local uname = "u_color"
	imaterial.set_property(gizmo_obj.sx.eid[1], uname, COLOR_X)
	imaterial.set_property(gizmo_obj.sx.eid[2], uname, COLOR_X)
	imaterial.set_property(gizmo_obj.sy.eid[1], uname, COLOR_Y)
	imaterial.set_property(gizmo_obj.sy.eid[2], uname, COLOR_Y)
	imaterial.set_property(gizmo_obj.sz.eid[1], uname, COLOR_Z)
	imaterial.set_property(gizmo_obj.sz.eid[2], uname, COLOR_Z)
	imaterial.set_property(gizmo_obj.uniform_scale_eid, uname, COLOR_GRAY)
end

function gizmo_sys:init()
    
end

local function updateGizmoScale()
	local camera = camerautil.main_queue_camera(world)
	local gizmo_dist = math3d.length(math3d.sub(camera.eyepos, math3d.vector(gizmo_obj.position)))
	gizmo_scale = gizmo_dist * 0.6
	gizmo_obj.root.transform.srt.s = math3d.vector(gizmo_scale, gizmo_scale, gizmo_scale)
end

local function updateAxisPlane()
	if gizmo_obj.mode ~= MOVE or not gizmo_obj.target_eid then
		return
	end
	local gizmoPosVec = math3d.vector(gizmo_obj.position)
	local plane_xy = {n = math3d.vector(DIR_Z), d = -math3d.dot(math3d.vector(DIR_Z), gizmoPosVec)}
	local plane_zx = {n = math3d.vector(DIR_Y), d = -math3d.dot(math3d.vector(DIR_Y), gizmoPosVec)}
	local plane_yz = {n = math3d.vector(DIR_X), d = -math3d.dot(math3d.vector(DIR_X), gizmoPosVec)}

	local camera = camerautil.main_queue_camera(world)
	local eyepos = camera.eyepos

	local project = math3d.sub(eyepos, math3d.mul(plane_xy.n, math3d.dot(plane_xy.n, eyepos) + plane_xy.d))
	local tp = math3d.totable(math3d.sub(project, gizmoPosVec))
	world[gizmo_obj.txy.eid[1]].transform.srt.t = {(tp[1] > 0) and move_plane_offset or -move_plane_offset, (tp[2] > 0) and move_plane_offset or -move_plane_offset, 0}
	gizmo_obj.txy.area = (tp[1] > 0) and ((tp[2] > 0) and RIGHT_TOP or RIGHT_BOTTOM) or (((tp[2] > 0) and LEFT_TOP or LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_zx.n, math3d.dot(plane_zx.n, eyepos) + plane_zx.d))
	tp = math3d.totable(math3d.sub(project, gizmoPosVec))
	world[gizmo_obj.tzx.eid[1]].transform.srt.t = {(tp[1] > 0) and move_plane_offset or -move_plane_offset, 0, (tp[3] > 0) and move_plane_offset or -move_plane_offset}
	gizmo_obj.tzx.area = (tp[1] > 0) and ((tp[3] > 0) and RIGHT_TOP or RIGHT_BOTTOM) or (((tp[3] > 0) and LEFT_TOP or LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_yz.n, math3d.dot(plane_yz.n, eyepos) + plane_yz.d))
	tp = math3d.totable(math3d.sub(project, gizmoPosVec))
	world[gizmo_obj.tyz.eid[1]].transform.srt.t = {0,(tp[2] > 0) and move_plane_offset or -move_plane_offset, (tp[3] > 0) and move_plane_offset or -move_plane_offset}
	gizmo_obj.tyz.area = (tp[3] > 0) and ((tp[2] > 0) and RIGHT_TOP or RIGHT_BOTTOM) or (((tp[2] > 0) and LEFT_TOP or LEFT_BOTTOM))
end

local function create_arrow_widget(axis_root, axis_str)
	local cone_t
	local cylindere_t
	local local_rotator
	if axis_str == "x" then
		cone_t = math3d.vector(axis_len, 0, 0)
		local_rotator = math3d.quaternion{0, 0, math.rad(-90)}
		cylindere_t = math3d.vector(0.5 * axis_len, 0, 0)
	elseif axis_str == "y" then
		cone_t = math3d.vector(0, axis_len, 0)
		local_rotator = math3d.quaternion{0, 0, 0}
		cylindere_t = math3d.vector(0, 0.5 * axis_len, 0)
	elseif axis_str == "z" then
		cone_t = math3d.vector(0, 0, axis_len)
		local_rotator = math3d.quaternion{math.rad(90), 0, 0}
		cylindere_t = math3d.vector(0, 0, 0.5 * axis_len)
	end
	local cylindereid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform =  {
				s = math3d.ref(math3d.vector(0.2, 10, 0.2)),
				r = local_rotator,
				t = cylindere_t,
			},
			material = world.component "resource" "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin',
			name = "arrow.cylinder" .. axis_str
		},
		action = {
            mount = axis_root,
		},
	}

	local coneeid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform =  {s = {1, 1.5, 1, 0}, r = local_rotator, t = cone_t},
			material = world.component "resource" "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone" .. axis_str
		},
		action = {
            mount = axis_root,
		},
	}

	if axis_str == "x" then
		gizmo_obj.tx.eid = {cylindereid, coneeid}
	elseif axis_str == "y" then
		gizmo_obj.ty.eid = {cylindereid, coneeid}
	elseif axis_str == "z" then
		gizmo_obj.tz.eid = {cylindereid, coneeid}
	end
end

function gizmo_sys:post_init()
	local cubeid = world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
			"ant.objcontroller|select",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible|selectable",
			transform =  {
				s={50},
				t={0, 0.5, 1, 0}
			},
			material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
			mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
			name = "test_cube",
		}
	}

	local coneeid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
			"ant.objcontroller|select",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible|selectable",
			transform = {
				s={50},
				t={-1, 0.5, 0}
			},
			material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "test_cone"
		},
	}

	imaterial.set_property(coneeid, "u_color", world.component "vector" {0, 0.5, 0.5, 1})

	local srt = {s = {1}, r = math3d.quaternion{0, 0, 0}, t = {0,0,0,1}}
	local axis_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = {},
			name = "axis root",
		},
	}
	gizmo_obj.root = world[axis_root]
	create_arrow_widget(axis_root, "x")
	create_arrow_widget(axis_root, "y")
	create_arrow_widget(axis_root, "z")
	local plane_xy_eid = computil.create_prim_plane_entity(
		{t = {move_plane_offset, move_plane_offset, 0, 1}, s = {move_plane_scale, 1, move_plane_scale, 0}, r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})},
		"/pkg/ant.resources/materials/t_gizmos.material",
		"plane_xy")
	imaterial.set_property(plane_xy_eid, "u_color", gizmo_obj.txy.color)
	world[plane_xy_eid].parent = axis_root
	gizmo_obj.txy.eid = {plane_xy_eid, plane_xy_eid}

	plane_yz_eid = computil.create_prim_plane_entity(
		{t = {0, move_plane_offset, move_plane_offset, 1}, s = {move_plane_scale, 1, move_plane_scale, 0}, r = math3d.tovalue(math3d.quaternion{0, 0, math.rad(90)})},
		"/pkg/ant.resources/materials/t_gizmos.material",
		"plane_yz")
	imaterial.set_property(plane_yz_eid, "u_color", gizmo_obj.tyz.color)
	world[plane_yz_eid].parent = axis_root
	gizmo_obj.tyz.eid = {plane_yz_eid, plane_yz_eid}

	plane_zx_eid = computil.create_prim_plane_entity(
		{t = {move_plane_offset, 0, move_plane_offset, 1}, s = {move_plane_scale, 1, move_plane_scale, 0}},
		"/pkg/ant.resources/materials/t_gizmos.material",
		"plane_zx")
	imaterial.set_property(plane_zx_eid, "u_color", gizmo_obj.tzx.color)
	world[plane_zx_eid].parent = axis_root
	gizmo_obj.tzx.eid = {plane_zx_eid, plane_zx_eid}
	resetMoveAxisColor()

	-- roate axis
	local uniform_rot_eid = computil.create_circle_entity(uniform_rot_axis_len, 72, {}, "rotate_gizmo_uniform")
	imaterial.set_property(uniform_rot_eid, "u_color", COLOR_GRAY)
	world[uniform_rot_eid].parent = axis_root
	gizmo_obj.rw.eid = {uniform_rot_eid, uniform_rot_eid}

	rot_eid = computil.create_circle_entity(axis_len, 72, {r = math3d.tovalue(math3d.quaternion{0, math.rad(90), 0})}, "rotate_gizmo_x")
	imaterial.set_property(rot_eid, "u_color", gizmo_obj.rx.color)
	world[rot_eid].parent = axis_root
	local line_eid = computil.create_line_entity({}, {0, 0, 0}, {axis_len, 0, 0})
	imaterial.set_property(line_eid, "u_color", gizmo_obj.rx.color)
	world[line_eid].parent = axis_root
	gizmo_obj.rx.eid = {rot_eid, line_eid}

	rot_eid = computil.create_circle_entity(axis_len, 72, {r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})}, "rotate_gizmo_y")
	imaterial.set_property(rot_eid, "u_color", gizmo_obj.ry.color)
	world[rot_eid].parent = axis_root
	line_eid = computil.create_line_entity({}, {0, 0, 0}, {0, axis_len, 0})
	imaterial.set_property(line_eid, "u_color", gizmo_obj.ry.color)
	world[line_eid].parent = axis_root
	gizmo_obj.ry.eid = {rot_eid, line_eid}

	rot_eid = computil.create_circle_entity(axis_len, 72, {}, "rotate_gizmo_z")
	imaterial.set_property(rot_eid, "u_color", gizmo_obj.rz.color)
	world[rot_eid].parent = axis_root
	line_eid = computil.create_line_entity({}, {0, 0, 0}, {0, 0, axis_len})
	imaterial.set_property(line_eid, "u_color", gizmo_obj.rz.color)
	world[line_eid].parent = axis_root
	gizmo_obj.rz.eid = {rot_eid, line_eid}

	-- scale axis
	local function create_scale_cube(srt, color, axis_name)
		local eid = world:create_entity {
			policy = {
				"ant.render|render",
				"ant.general|name",
				"ant.scene|hierarchy_policy",
			},
			data = {
				scene_entity = true,
				state = ies.create_state "visible",
				transform = srt,
				material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
				mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
				name = "scale_cube" .. axis_name
			}
		}
		imaterial.set_property(eid, "u_color", color)
		return eid
	end
	-- scale axis cube
	local cube_eid = create_scale_cube({s = axis_cube_scale}, COLOR_GRAY, "0")
	world[cube_eid].parent = axis_root
	gizmo_obj.uniform_scale_eid = cube_eid
	cube_eid = create_scale_cube({t = {axis_len, 0, 0, 1}, s = axis_cube_scale}, COLOR_X, "x")
	world[cube_eid].parent = axis_root
	line_eid = computil.create_line_entity({}, {0, 0, 0}, {axis_len, 0, 0})
	imaterial.set_property(line_eid, "u_color", COLOR_X)
	world[line_eid].parent = axis_root
	gizmo_obj.sx.eid = {cube_eid, line_eid}

	cube_eid = create_scale_cube({t = {0, axis_len, 0, 1}, s = axis_cube_scale}, COLOR_Y, "y")
	world[cube_eid].parent = axis_root
	line_eid = computil.create_line_entity({}, {0, 0, 0}, {0, axis_len, 0})
	imaterial.set_property(line_eid, "u_color", COLOR_Y)
	world[line_eid].parent = axis_root
	gizmo_obj.sy.eid = {cube_eid, line_eid}

	cube_eid = create_scale_cube({t = {0, 0, axis_len, 1}, s = axis_cube_scale}, COLOR_Z, "z")
	world[cube_eid].parent = axis_root
	line_eid = computil.create_line_entity({}, {0, 0, 0}, {0, 0, axis_len})
	imaterial.set_property(line_eid, "u_color", COLOR_Z)
	world[line_eid].parent = axis_root
	gizmo_obj.sz.eid = {cube_eid, line_eid}

	showGizmoByState(false)
end

local keypress_mb = world:sub{"keyboard"}

local pickup_mb = world:sub {"pickup"}

local icamera = world:interface "ant.scene|camera"
local function worldToScreen(world_pos)
	local mq = world:singleton_entity "main_queue"
	local vp = icamera.viewproj(mq.camera_eid)
	local proj_pos = math3d.totable(math3d.transform(vp, world_pos, 1))
	local sw, sh = rhwi.screen_size()
	return {(1 + proj_pos[1] / proj_pos[4]) * sw * 0.5, (1 - proj_pos[2] / proj_pos[4]) * sh * 0.5, 0}
end

local function pointToLineDistance2D(p1, p2, p3)
	local dx = p2[1] - p1[1];
	local dy = p2[2] - p1[2];
	if (dx + dy == 0) then
		return math.sqrt((p3[1] - p1[1]) * (p3[1] - p1[1]) + (p3[2] - p1[2]) * (p3[2] - p1[2]));
	end
	local u = ((p3[1] - p1[1]) * dx + (p3[2] - p1[2]) * dy) / (dx * dx + dy * dy);
	if u < 0 then
		return math.sqrt((p3[1] - p1[1]) * (p3[1] - p1[1]) + (p3[2] - p1[2]) * (p3[2] - p1[2]));
	elseif u > 1 then
		return math.sqrt((p3[1] - p2[1]) * (p3[1] - p2[1]) + (p3[2] - p2[2]) * (p3[2] - p2[2]));
	else
		local x = p1[1] + u * dx;
		local y = p1[2] + u * dy;
		return math.sqrt((p3[1] - x) * (p3[1] - x) + (p3[2] - y) * (p3[2] - y));
	end
end

local function viewToAxisConstraint(point, axis, origin)
	local q = world:singleton_entity("main_queue")
	local ray = iom.ray(q.camera_eid, point)
	local raySrc = ray.origin
	local mq = world:singleton_entity "main_queue"
	local cameraPos = iom.get_position(mq.camera_eid)

	-- find plane between camera and initial position and direction
	--local cameraToOrigin = math3d.sub(cameraPos - math3d.vector(origin[1], origin[2], origin[3]))
	local cameraToOrigin = math3d.sub(cameraPos, origin)
	local axisVec = math3d.vector(axis)
	local lineViewPlane = math3d.normalize(math3d.cross(cameraToOrigin, axisVec))

	-- Now we project the ray from origin to the source point to the screen space line plane
	local cameraToSrc = math3d.normalize(math3d.sub(raySrc, cameraPos))

	local perpPlane = math3d.cross(cameraToSrc, lineViewPlane)

	-- finally, project along the axis to perpPlane
	local factor = (math3d.dot(perpPlane, cameraToOrigin) / math3d.dot(perpPlane, axisVec))
	return math3d.totable(math3d.mul(factor, axisVec))
end


local rotateHitRadius = 0.02
local moveHitRadiusPixel = 10

local function rayHitPlane(ray, plane_info)
	local plane = {n = plane_info.dir, d = -math3d.dot(math3d.vector(plane_info.dir), math3d.vector(plane_info.pos))}

	local rayOriginVec = ray.origin
	local rayDirVec = ray.dir
	local planeDirVec = math3d.vector(plane.n[1], plane.n[2], plane.n[3])
	
	local d = math3d.dot(planeDirVec, rayDirVec)
	if math.abs(d) > 0.00001 then
		local t = -(math3d.dot(planeDirVec, rayOriginVec) + plane.d) / d
		if t >= 0.0 then
			return math3d.vector(ray.origin[1] + t * ray.dir[1], ray.origin[2] + t * ray.dir[2], ray.origin[3] + t * ray.dir[3])
		end	
	end
	return nil
end

local function mouseHitPlane(screen_pos, plane_info)
	local q = world:singleton_entity("main_queue")
	return rayHitPlane(iom.ray(q.camera_eid, screen_pos), plane_info)
end

local function selectAxisPlane(x, y)
	if gizmo_obj.mode ~= MOVE then
		return nil
	end
	local function hitTestAxixPlane(axis_plane)
		local hitPosVec = mouseHitPlane({x, y}, {dir = axis_plane.dir, pos = gizmo_obj.position})
		if hitPosVec then
			return math3d.totable(math3d.sub(hitPosVec, math3d.vector(gizmo_obj.position)))
		end
		return nil
	end
	local planeHitRadius = gizmo_scale * move_plane_hit_radius * 0.5
	local axis_plane = gizmo_obj.tyz
	local posToGizmo = hitTestAxixPlane(axis_plane)
	if posToGizmo then
		if axis_plane.area == RIGHT_BOTTOM then
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == LEFT_BOTTOM then
			posToGizmo[3] = -posToGizmo[3]
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == LEFT_TOP then
			posToGizmo[3] = -posToGizmo[3]
		end
		if posToGizmo[2] > 0 and posToGizmo[2] < planeHitRadius and posToGizmo[3] > 0 and posToGizmo[3] < planeHitRadius then
			imaterial.set_property(axis_plane.eid[1], "u_color", HIGHTLIGHT_COLOR_ALPHA)
			imaterial.set_property(gizmo_obj.ty.eid[1], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(gizmo_obj.ty.eid[2], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(gizmo_obj.tz.eid[1], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(gizmo_obj.tz.eid[2], "u_color", gizmo_obj.highlight_color)
			return axis_plane
		end
	end
	posToGizmo = hitTestAxixPlane(gizmo_obj.txy)
	axis_plane = gizmo_obj.txy
	if posToGizmo then
		if axis_plane.area == RIGHT_BOTTOM then
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == LEFT_BOTTOM then
			posToGizmo[1] = -posToGizmo[1]
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == LEFT_TOP then
			posToGizmo[1] = -posToGizmo[1]
		end
		if posToGizmo[1] > 0 and posToGizmo[1] < planeHitRadius and posToGizmo[2] > 0 and posToGizmo[2] < planeHitRadius then
			imaterial.set_property(axis_plane.eid[1], "u_color", HIGHTLIGHT_COLOR_ALPHA)
			imaterial.set_property(gizmo_obj.tx.eid[1], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(gizmo_obj.tx.eid[2], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(gizmo_obj.ty.eid[1], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(gizmo_obj.ty.eid[2], "u_color", gizmo_obj.highlight_color)
			return axis_plane
		end
	end
	posToGizmo = hitTestAxixPlane(gizmo_obj.tzx)
	axis_plane = gizmo_obj.tzx
	if posToGizmo then
		if axis_plane.area == RIGHT_BOTTOM then
			posToGizmo[3] = -posToGizmo[3]
		elseif axis_plane.area == LEFT_BOTTOM then
			posToGizmo[1] = -posToGizmo[1]
			posToGizmo[3] = -posToGizmo[3]
		elseif axis_plane.area == LEFT_TOP then
			posToGizmo[1] = -posToGizmo[1]
		end
		if posToGizmo[1] > 0 and posToGizmo[1] < planeHitRadius and posToGizmo[3] > 0 and posToGizmo[3] < planeHitRadius then
			imaterial.set_property(axis_plane.eid[1], "u_color", HIGHTLIGHT_COLOR_ALPHA)
			imaterial.set_property(gizmo_obj.tz.eid[1], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(gizmo_obj.tz.eid[2], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(gizmo_obj.tx.eid[1], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(gizmo_obj.tx.eid[2], "u_color", gizmo_obj.highlight_color)
			return axis_plane
		end
	end
	return nil
end

local function selectAxis(x, y)
	if not gizmo_obj.target_eid then
		return
	end
	if gizmo_obj.mode == SCALE then
		resetScaleAxisColor()
	elseif gizmo_obj.mode == MOVE then
		resetMoveAxisColor()
	end
	-- by plane
	local axisPlane = selectAxisPlane(x, y)
	if axisPlane then
		return axisPlane
	end

	local hp = {x, y, 0}
	local start = worldToScreen(math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3]))
	uniform_scale = false
	-- uniform scale
	if gizmo_obj.mode == SCALE then
		local radius = math3d.length(math3d.sub(hp, start))
		if radius < moveHitRadiusPixel then
			uniform_scale = true
			imaterial.set_property(gizmo_obj.uniform_scale_eid, "u_color", gizmo_obj.highlight_color)
			return nil
		end
	end
	-- by axis
	local end_x = worldToScreen(math3d.vector(gizmo_obj.position[1] + axis_len * gizmo_scale, gizmo_obj.position[2], gizmo_obj.position[3]))
	
	local ret = pointToLineDistance2D(start, end_x, hp)
	local axis = gizmo_obj.tx
	if gizmo_obj.mode == SCALE then
		axis = gizmo_obj.sx
	end
	if ret < moveHitRadiusPixel then
		imaterial.set_property(axis.eid[1], "u_color", gizmo_obj.highlight_color)
		imaterial.set_property(axis.eid[2], "u_color", gizmo_obj.highlight_color)
		return axis
	end

	local end_y = worldToScreen(math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2] + axis_len * gizmo_scale, gizmo_obj.position[3]))
	ret = pointToLineDistance2D(start, end_y, hp)
	axis = gizmo_obj.ty
	if gizmo_obj.mode == SCALE then
		axis = gizmo_obj.sy
	end
	if ret < moveHitRadiusPixel then
		imaterial.set_property(axis.eid[1], "u_color", gizmo_obj.highlight_color)
		imaterial.set_property(axis.eid[2], "u_color", gizmo_obj.highlight_color)
		return axis
	end

	local end_z = worldToScreen(math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3] + axis_len * gizmo_scale))
	ret = pointToLineDistance2D(start, end_z, hp)
	axis = gizmo_obj.tz
	if gizmo_obj.mode == SCALE then
		axis = gizmo_obj.sz
	end
	if ret < moveHitRadiusPixel then
		imaterial.set_property(axis.eid[1], "u_color", gizmo_obj.highlight_color)
		imaterial.set_property(axis.eid[2], "u_color", gizmo_obj.highlight_color)
		return axis
	end
	return nil
end

local function selectRotateAxis(x, y)
	if not gizmo_obj.target_eid then
		return
	end
	resetRotateAxisColor()

	local function hittestRotateAxis(axis)
		local hitPosVec = mouseHitPlane({x, y}, {dir = axis.dir, pos = gizmo_obj.position})
		if not hitPosVec then
			return
		end
		local dist = math3d.length(math3d.sub(math3d.vector(gizmo_obj.position), hitPosVec))
		local adjust_axis_len = axis_len
		if axis == gizmo_obj.rw then
			adjust_axis_len = uniform_rot_axis_len
		end
		if math.abs(dist - gizmo_scale * adjust_axis_len) < rotateHitRadius * gizmo_scale then
			imaterial.set_property(axis.eid[1], "u_color", gizmo_obj.highlight_color)
			imaterial.set_property(axis.eid[2], "u_color", gizmo_obj.highlight_color)
			return hitPosVec
		else
			imaterial.set_property(axis.eid[1], "u_color", axis.color)
			imaterial.set_property(axis.eid[2], "u_color", axis.color)
			return nil
		end
	end

	local hit = hittestRotateAxis(gizmo_obj.rx)
	if hit then
		return gizmo_obj.rx, hit
	end

	hit = hittestRotateAxis(gizmo_obj.ry)
	if hit then
		return gizmo_obj.ry, hit
	end

	hit = hittestRotateAxis(gizmo_obj.rz)
	if hit then
		return gizmo_obj.rz, hit
	end

	hit = hittestRotateAxis(gizmo_obj.rw)
	if hit then
		return gizmo_obj.rw, hit
	end
end

local cameraZoom = world:sub {"camera", "zoom"}
local mouseDrag = world:sub {"mousedrag"}
local mouseMove = world:sub {"mousemove"}
local mouseDown = world:sub {"mousedown"}
local mouseUp = world:sub {"mouseup"}

local gizmoState = world:sub {"gizmo"}

local lastMousePos
local lastGizmoPos
local initOffset
local lastGizmoScale

local function moveGizmo(x, y)
	if not gizmo_obj.target_eid then
		return
	end
	if move_axis == gizmo_obj.txy or move_axis == gizmo_obj.tyz or move_axis == gizmo_obj.tzx then
		local downpos = mouseHitPlane(lastMousePos, {dir = move_axis.dir, pos = gizmo_obj.position})
		local curpos = mouseHitPlane({x, y}, {dir = move_axis.dir, pos = gizmo_obj.position})
		if downpos and curpos then
			local deltapos = math3d.totable(math3d.sub(curpos, downpos))
			gizmo_obj.position = {
				lastGizmoPos[1] + deltapos[1],
				lastGizmoPos[2] + deltapos[2],
				lastGizmoPos[3] + deltapos[3]
			}
		end
	else
		local newOffset = viewToAxisConstraint({x, y}, move_axis.dir, lastGizmoPos)
		local deltaOffset = {newOffset[1] - initOffset[1], newOffset[2] - initOffset[2], newOffset[3] - initOffset[3]}
		gizmo_obj.position = {
			lastGizmoPos[1] + deltaOffset[1],
			lastGizmoPos[2] + deltaOffset[2],
			lastGizmoPos[3] + deltaOffset[3]
		}
	end
	local new_pos = math3d.vector(gizmo_obj.position)
	gizmo_obj.root.transform.srt.t = new_pos
	world[gizmo_obj.target_eid].transform.srt.t = new_pos
	updateGizmoScale()
end
local lastRotateAxis = math3d.ref()
local lastRotate = math3d.ref()
local lastHit = math3d.ref()
local updateClockwise = false
local clockwise = false
local function rotateGizmo(x, y)
	local hitPosVec = mouseHitPlane({x, y}, {dir = rotate_axis.dir, pos = gizmo_obj.position})
	if not hitPosVec then
		return
	end
	local tangent = math3d.normalize(math3d.cross(rotate_axis.dir, math3d.normalize(math3d.sub(lastHit, math3d.vector(gizmo_obj.position)))))
	local proj_len = math3d.dot(tangent, math3d.sub(hitPosVec, lastHit))

	local deltaAngle = proj_len * 200 / gizmo_scale
	local quat
	if rotate_axis == gizmo_obj.rx then
		quat = math3d.quaternion { axis = lastRotateAxis, r = math.rad(deltaAngle) }
	elseif rotate_axis == gizmo_obj.ry then
		quat = math3d.quaternion { axis = lastRotateAxis, r = math.rad(deltaAngle) }
	elseif rotate_axis == gizmo_obj.rz then
		quat = math3d.quaternion { axis = lastRotateAxis, r = math.rad(deltaAngle) }
	elseif rotate_axis == gizmo_obj.rw then
		local mq = world:singleton_entity "main_queue"
		local viewdir = iom.get_direction(mq.camera_eid)
		quat = math3d.quaternion { axis = math3d.normalize(viewdir), r = math.rad(deltaAngle) }
	end
	
	world[gizmo_obj.target_eid].transform.r = math3d.mul(lastRotate, quat)
end

local function scaleGizmo(x, y)
	local newScale
	if uniform_scale then
		local delta_x = x - lastMousePos[1]
		local delta_y = lastMousePos[2] - y
		local factor = (delta_x + delta_y) / 60.0
		local scaleFactor = 1.0
		if factor < 0 then
			scaleFactor = 1 / (1 + math.abs(factor))
		else
			scaleFactor = 1 + factor
		end
		newScale = {lastGizmoScale[1] * scaleFactor, lastGizmoScale[2] * scaleFactor, lastGizmoScale[3] * scaleFactor}
	else
		newScale = {lastGizmoScale[1], lastGizmoScale[2], lastGizmoScale[3]}
		local newOffset = viewToAxisConstraint({x, y}, move_axis.dir, lastGizmoPos)
		local deltaOffset = {newOffset[1] - initOffset[1], newOffset[2] - initOffset[2], newOffset[3] - initOffset[3]}
		local scaleFactor = (1.0 + 3.0 * math3d.length(deltaOffset))
		if move_axis.dir == DIR_X then
			if deltaOffset[1] < 0 then
				newScale[1] = lastGizmoScale[1] / scaleFactor
			else
				newScale[1] = lastGizmoScale[1] * scaleFactor
			end
		elseif move_axis.dir == DIR_Y then
			if deltaOffset[2] < 0 then
				newScale[2] = lastGizmoScale[2] / scaleFactor
			else
				newScale[2] = lastGizmoScale[2] * scaleFactor
			end
			
		elseif move_axis.dir == DIR_Z then
			if deltaOffset[3] < 0 then
				newScale[3] = lastGizmoScale[3] / scaleFactor
			else
				newScale[3] = lastGizmoScale[3] * scaleFactor
			end
		end

	end
	if gizmo_obj.target_eid then
		world[gizmo_obj.target_eid].transform.srt.s = newScale
	end
end

local gizmo_seleted = false
function gizmo_obj:selectGizmo(x, y)
	if self.mode == MOVE or self.mode == SCALE then
		move_axis = selectAxis(x, y)
		if move_axis or uniform_scale then
			lastMousePos = {x, y}
			lastGizmoScale = math3d.totable(world[gizmo_obj.target_eid].transform.srt.s)
			if move_axis then
				lastGizmoPos = {gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3]}
				initOffset = viewToAxisConstraint(lastMousePos, move_axis.dir, lastGizmoPos)
			end
			return true
		end
	elseif self.mode == ROTATE then
		rotate_axis, lastHit.v = selectRotateAxis(x, y)
		if rotate_axis then
			updateClockwise = true
			lastRotateAxis.v = math3d.transform(math3d.inverse(world[gizmo_obj.target_eid].transform.r), rotate_axis.dir, 0)
			lastRotate.q = world[gizmo_obj.target_eid].transform.r
			return true
		end
	end
	return false
end

function gizmo_sys:data_changed()
	for _ in cameraZoom:unpack() do
		updateGizmoScale()
	end

	for _, what in gizmoState:unpack() do
		if what == "select" then
			onGizmoMode(SELECT)
		elseif what == "rotate" then
			onGizmoMode(ROTATE)
		elseif what == "move" then
			onGizmoMode(MOVE)
		elseif what == "scale" then
			onGizmoMode(SCALE)
		end
	end

	for _, what, x, y in mouseDown:unpack() do
		if what == "LEFT" then
			gizmo_seleted = gizmo_obj:selectGizmo(x, y)
		end
	end

	for _, what, x, y in mouseUp:unpack() do
		if what == "LEFT" then
			gizmo_seleted = false
		elseif what == "RIGHT" then
			updateAxisPlane()
		end
	end

	for _, what, x, y in mouseMove:unpack() do
		if what == "UNKNOWN" then
			if gizmo_obj.mode == MOVE or gizmo_obj.mode == SCALE then
				selectAxis(x, y)
			elseif gizmo_obj.mode == ROTATE then
				selectRotateAxis(x, y)
			end
		end
	end
	
	for _, what, x, y, dx, dy in mouseDrag:unpack() do
		if what == "LEFT" then
			if gizmo_obj.mode == MOVE and move_axis then
				moveGizmo(x, y)
			elseif gizmo_obj.mode == SCALE then
				if move_axis or uniform_scale then
					scaleGizmo(x, y)
				end
			elseif gizmo_obj.mode == ROTATE and rotate_axis then
				rotateGizmo(x, y)
			else
				world:pub { "camera", "pan", dx, dy }
			end
		elseif what == "RIGHT" then
			world:pub { "camera", "rotate", dx, dy }
			updateGizmoScale()
		end
	end

	for _,pick_id,pick_ids in pickup_mb:unpack() do
        local eid = pick_id
        if eid and world[eid] then
			if gizmo_obj.mode ~= SELECT and gizmo_obj.target_eid ~= eid then
				gizmo_obj.position = math3d.totable(world[eid].transform.t)
				gizmo_obj.root.transform.t = world[eid].transform.t
				gizmo_obj.target_eid = eid
				updateGizmoScale()
				updateAxisPlane()
				showGizmoByState(true)
			end
		else
			if not gizmo_seleted then
				gizmo_obj.target_eid = nil
				showGizmoByState(false)
			end
		end
	end

	if gizmo_obj.rw.eid[1] then
		local mq = world:singleton_entity "main_queue"
		gizmo_obj.rw.dir = iom.get_direction(mq.camera_eid)

		local iv = icamera.worldmat(mq.camera_eid)
		local s,r,t = math3d.srt(iv)
		world[gizmo_obj.rw.eid[1]].transform.srt.r = r
	end
end