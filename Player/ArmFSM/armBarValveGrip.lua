local state = {}
state._NAME = ...
require'hcm'
local vector = require'vector'
local util   = require'util'
local movearm = require'movearm'
local libArmPlan = require 'libArmPlan'
local arm_planner = libArmPlan.new_planner()

--Door opening state using HOOK
local handle_clearance = vector.new({0,0,-0.05})
local lhand_rpy0 = {0*Body.DEG_TO_RAD,0,0}
local rhand_rpy0 = {-0*Body.DEG_TO_RAD,0,0}
local trLArm1, trRArm1
local stage

local qLArmInit0,qRArmInit0,qLArmInit1,qRArmInit1

function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry

  local qLArm = Body.get_larm_command_position()
  local qRArm = Body.get_rarm_command_position()
  
  qLArm0 = qLArm
  qRArm0 = Body.get_inverse_arm_given_wrist( qRArm, {0,0,0, unpack(rhand_rpy0)})
  
  trLArm0 = Body.get_forward_larm(qLArm0)
  trRArm0 = Body.get_forward_rarm(qRArm0)  


  arm_planner:reset_torso_comp(qLArm0, qRArm0)
  arm_planner:save_boundary_condition({qLArm0, qRArm0, qLArm0, qRArm0, {0,0}})
  stage = "wristturn";  
end


function state.update()
--  print(state._NAME..' Update' )
  -- Get the time of update
  if plan_failed then return "planfail" end
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t
  --if t-t_entry > timeout then return'timeout' end
  

  if stage=="wristturn" then --Turn yaw angles first
    if movearm.setArmJoints(qLArm0,qRArm0,dt, Config.arm.joint_init_limit) ==1 then       
      local trRArmTarget1 = {0.20,-0.24,-0.10, unpack(rhand_rpy0)}
      local trRArmTarget2 = {0.30,-0.10, 0.10, unpack(rhand_rpy0)}
      local arm_seq = {
        mass={0,0},
        armseq={
          {trLArm0, trRArmTarget1},
          {trLArm0, trRArmTarget2},
        }
      }
      if arm_planner:plan_arm_sequence(arm_seq) then stage = "armup" end      
    end
  elseif stage=="armup" then       
    if arm_planner:play_arm_sequence(t) then 
      stage="armposition"
    end
  elseif stage=="armposition" then --Move the arm forward using IK now     
    
  end
 
end

function state.exit()  
  print(state._NAME..' Exit' )
end

return state
