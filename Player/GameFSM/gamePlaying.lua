local state = {}
state._NAME = ...

local Body = require'Body'
local t_entry, t_update

function state.entry()
  print(state._NAME..' Entry' ) 
  -- When entry was previously called
  local t_entry_prev = t_entry
  -- Update the time of entry
  t_entry = Body.get_time()
  t_update = t_entry

--Gcm variables
-- 0 for initial / 1 for ready 2 for set / 3 for play / 4 fin
-- 5: Pre-initialized (idle) 6 for testing
  gcm.set_game_state(3)
  if gcm.get_game_role()==0 then
    --goalie
    head_ch:send'scangoalie'
  elseif gcm.get_game_role()==1 then 
    head_ch:send'scanobs'
  elseif gcm.get_game_role()==3 then  --test
    head_ch:send'scangoalie'
  end  
  if gcm.get_game_role()==2 then  --force stop
    return 'finish'
  end

end

function state.update()

  local t = Body.get_time()
  local t_diff = t - t_update
  -- Save this at the last update time
  
  t_update = t


  qLArm = Body.get_larm_position()
  qRArm = Body.get_rarm_position()  
  local threshold = 45*DEG_TO_RAD
  local qL = util.mod_angle(qLArm[1])
  local qR = util.mod_angle(qRArm[1])
--  print(qL*RAD_TO_DEG,qR*RAD_TO_DEG)
  if qL<45*DEG_TO_RAD and qL>-45*DEG_TO_RAD and
    qR<45*DEG_TO_RAD and qR>-45*DEG_TO_RAD and
     gcm.get_game_role()==3 then  --test
    return 'finish'
  end


end

function state.exit()
  print(state._NAME..' Exit' ) 
end

return state
