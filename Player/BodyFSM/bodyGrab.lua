local state = {}
state._NAME = ...

local Body = require'Body'
local T = require'libTransform'
local K = Body.Kinematics
local vector = require'vector'

--local timeout = 10.0
local t_entry, t_update, t_exit

-- Min/Switch pitch/Max range
local min_r, mid_r, max_r = .25, .3, .39
--local object_coord = vector.new{.275,.275,-.175} --max
--local object_coord = vector.new{.18,.18,-.175}
local object_coord = vector.new{.27,.27,-.175}
--local object_coord = vector.new{.25,0,-.175}
local object_r = math.sqrt(object_coord[1]^2+object_coord[2]^2)
assert(object_r>min_r and object_r<max_r,"Cannot reach!")

local stages = {}
local function init_stages()
	-- Open on the right side
	table.insert(stages,
		{tr=T.rotZ(math.pi/1.01)*T.trans(.2,0,0)*T.rotY(math.pi/1.01),
			dt=2,gr=0.0115})
	-- To the right side
	table.insert(stages,
		{tr=T.rotZ(math.pi/1.01)*T.trans(.2,0,0)*T.rotY(math.pi/1.01),dt=2})


	-- Left side back up
	table.insert(stages,
		{tr=T.trans(object_coord[1],object_coord[2],-.1)
			*T.rotY(object_r<mid_r and math.pi/1.01 or math.pi/1.3),
			dt=2})

	-- Left side down w/ grip
	table.insert(stages,
		{tr=T.trans(unpack(object_coord))
			*T.rotY(object_r<mid_r and math.pi/1.01 or math.pi/1.3),
			dt=2,gr=0.0025})
	-- Left side down
	table.insert(stages,
		{tr=T.trans(unpack(object_coord))
			*T.rotY(object_r<mid_r and math.pi/1.01 or math.pi/1.3),
			dt=2})

	-- Left side
	table.insert(stages,
		{tr=T.trans(object_coord[1],object_coord[2],.2)*T.rotY(math.pi/2),
			dt=2,gr=0.0115})
	--[[
	-- Low
	table.insert(stages,
		{tr=T.trans(.3,0,.2)*T.rotY(math.pi/2),dt=2})
	--]]
	-- High
	table.insert(stages,
		{tr=T.trans(.3,0,.125)*T.rotY(math.pi/2),dt=2})
	-- Up
	table.insert(stages,
		{q=vector.zeros(Body.nJoint),dt=2})
end

local t_stage, tr_stage, id_stage, q_stage, iqArm

function state.entry()
  print(state._NAME..' Entry' )
	init_stages()
  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  t_entry = Body.get_time()
  t_update = t_entry
	id_stage = #stages
	local s = table.remove(stages)
	t_stage = t_entry + s.dt
	if s.tr then
		tr_stage = s.tr
		iqArm = vector.new(K.inverse_arm(tr_stage))
		Body.set_command_position(iqArm)
	elseif s.q then
		q_stage = s.q
		Body.set_command_position(s.q)
	end
	if s.gr then jcm.set_gripper_command_position({s.gr,0}) end
end

function state.update()
  --print(state._NAME..' Update' )
  -- Get the time of update
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t
  --if t-t_entry > timeout then return'timeout' end
	if t-t_stage>0 then
		id_stage = #stages
		local s = table.remove(stages)
		if not s then return'done' end
		t_stage = t + s.dt
		if s.tr then
			tr_stage = s.tr
			iqArm = vector.new(K.inverse_arm(tr_stage))
			Body.set_command_position(iqArm)
		elseif s.q then
			q_stage = s.q
			Body.set_command_position(s.q)
		end
		if s.gr then jcm.set_gripper_command_position({s.gr,0}) end
	end

end

function state.exit()
  print(state._NAME..' Exit' )
  t_exit = Body.get_time()
end

return state
