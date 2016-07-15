--------------------------------
-- Humanoid arm state
-- (c) 2013 Stephen McGill, Seung-Joon Yi
--------------------------------
local state = {}
state._NAME = ...

local Body   = require'Body'
local vector = require'vector'
local movearm = require'movearm'

local t_entry, t_update, t_finish
local timeout = 30.0

-- left and right will both request waist positions potentially
local lco, rco
local okL, qLWaypoint, qLWaist
local okR, qRWaypoint, qRWaist
local sequence, s, stage

function state.entry()
	io.write(state._NAME, ' Entry\n')
	local t_entry_prev = t_entry
	t_entry = Body.get_time()
	t_update = t_entry


--[[
grasping = {}

table.insert(grasping, {
	--left = false,
	left = {
		timeout=8,
		via='jacobian_preplan',
		tr={0.28, 0.23, 0.42, 0*DEG_TO_RAD, -80*DEG_TO_RAD, 0*DEG_TO_RAD},
		qArmGuess = vector.new{60, 10, 0, -135, 0, 30, 0}*DEG_TO_RAD,
		weights = {0,1,0,1},
	},
	right = {
		timeout=8,
		via='jacobian_preplan',
		tr={0.31, -0.23, 0.37, 0*DEG_TO_RAD, -80*DEG_TO_RAD, 0*DEG_TO_RAD},
		qArmGuess = vector.new{75, -10, -5, -135, -10, -12, 10}*DEG_TO_RAD,
		weights = {0,1,0,1},
	}
})

]]--
-- Weights: cusage, cdiff, ctight, cshoulder, cwrist
grasping = {}

table.insert(grasping, {
	right = false,
	left = {
		timeout=10,
		via='jacobian_preplan',
		tr={0.55, 0.246, 0.0, 0*DEG_TO_RAD, 0*DEG_TO_RAD, 0*DEG_TO_RAD},
		--qArmGuess = vector.new{-15, 60, 90, -120, -80, -70, 0}*DEG_TO_RAD,
		weights = {1,1,1},
	}	
})



	sequence = {unpack(grasping)}

	s = 1
	stage = sequence[s]
	lco, rco = movearm.goto(stage.left, stage.right)



	print('Received a plan')
	local lco, rco = movearm.goto(stage.left, stage.right)
	local wpath = {}
	--
	local lpath = {}
	if type(lco)=='thread' then
		while coroutine.status(lco)~='dead' do
			local okL, qLWaypoint, qWaistpoint = coroutine.resume(lco)
			print('jwhuh', okL, qLWaypoint)

			table.insert(lpath, qLWaypoint)
			if qWaistpoint then table.insert(wpath, qWaistpoint) end
		end
	else
		print('lco', lco)
	end
	local rpath = {}
	if type(rco)=='thread' then
		while coroutine.status(rco)~='dead' do
			local okR, qRWaypoint, qWaistpoint = coroutine.resume(rco)
			table.insert(rpath, qRWaypoint)
			if qWaistpoint then table.insert(wpath, qWaistpoint) end
		end
	else
		print('rco', rco)
	end
	-- TODO: Check that the waist was not twice populated
	print('Sending the paths',#lpath, #rpath, #wpath)
--	return {lpath, rpath, wpath}






















	sequence = {unpack(Config.arm.drill)}

	s = 1
	stage = sequence[s]
	lco, rco = movearm.goto(stage.left, stage.right)


















	-- Check for no motion
	okL = type(lco)=='thread' or lco==false
	okR = type(rco)=='thread' or rco==false
	qLWaypoint = nil
	qRWaypoint = nil
	qLWaistpoint = nil
	qRWaistpoint = nil

end

function state.update()
	--  io.write(state._NAME,' Update\n')
	local t  = Body.get_time()
	local dt = t - t_update
	t_update = t
	--if t-t_entry > timeout then return'timeout' end

	if not stage then return'done' end

	local lStatus = type(lco)=='thread' and coroutine.status(lco) or 'dead'
	local rStatus = type(rco)=='thread' and coroutine.status(rco) or 'dead'

	local qLArm = Body.get_larm_position()
	local qRArm = Body.get_rarm_position()
	local qWaist = Body.get_safe_waist_position()
	if lStatus=='suspended' then
		okL, qLWaypoint, qLWaistpoint = coroutine.resume(lco, qLArm, qWaist)
	end
	if rStatus=='suspended' then
		okR, qRWaypoint, qRWaistpoint = coroutine.resume(rco, qRArm, qWaist)
	end

	-- Check if errors in either
	if not okL or not okR then
		print(state._NAME, 'L', okL, qLWaypoint, lco, lStatus)
		print(state._NAME, 'R', okR, qRWaypoint, rco, rStatus)
		-- Safety
		local qcLArm = Body.get_larm_command_position()
		local qcRArm = Body.get_rarm_command_position()
		local qcWaist = Body.get_safe_waist_command_position()
		--
		Body.set_larm_command_position(qcLArm)
		Body.set_rarm_command_position(qcRArm)
		Body.set_safe_waist_command_position(qcWaist)
		--
		return'teleopraw'
	end

	if type(qLWaypoint)=='table' then
		Body.set_larm_command_position(qLWaypoint)
	end
	if type(qRWaypoint)=='table' then
		Body.set_rarm_command_position(qRWaypoint)
	end

	--[[
	if qLWaistpoint and qRWaistpoint then
		print('Conflicting Waist')
	elseif qLWaist then
		Body.set_safe_waist_command_position(qLWaistpoint)
	elseif qRWaist then
		Body.set_safe_waist_command_position(qRWaistpoint)
	end
	--]]
	  -- Zero the waist
  local qWaist = Body.get_safe_waist_command_position()
  local qWaist_approach, doneWaist = util.approachTol(qWaist, {0,0}, {2 * DEG_TO_RAD, 2 * DEG_TO_RAD}, dt, {1*DEG_TO_RAD, 1*DEG_TO_RAD})
  Body.set_safe_waist_command_position(qWaist_approach)

	-- Check if done
	if lStatus=='dead' and rStatus=='dead' then
		-- Goto the nextitem in the sequnce
		s = s + 1
		stage = sequence[s]
		if stage then
			print('Next sequence:', s, stage)
			lco, rco = movearm.goto(stage.left, stage.right)
			okL = type(lco)=='thread' or lco==false
			okR = type(rco)=='thread' or rco==false
		else
			return doneWaist and 'done'
		end
	end

end

function state.exit()
	print(state._NAME..' Exit')

end

return state
