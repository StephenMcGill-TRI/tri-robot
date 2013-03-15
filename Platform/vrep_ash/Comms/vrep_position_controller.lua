require('pid')

--[[
console = simAuxiliaryConsoleOpen("Aux Console", 500, 0x10)
print = function(...)
  simAuxiliaryConsolePrint(console, ...)
end
--]]

local MAX_FORCE = 300
local MAX_VELOCITY = 100
local POSITION_P_GAIN_FACTOR = 1000
local POSITION_I_GAIN_FACTOR = 1000
local POSITION_D_GAIN_FACTOR = 1000

vrep_position_controller = {}
vrep_position_controller.__index = vrep_position_controller

function vrep_position_controller.new(...)
  -- Following data is handed over from V-REP:
  ------------------------------------------------------------------------------
  local init, revolute, cyclic, jointHandle, passCnt, totalPasses,
  currentPos, targetPos, errorValue, effort, dynStepSize, lowLimit,
  hightLimit, targetVel, maxForceTorque, velUpperLimit = ...

  local o = {}
  o.position_pid = pid.new(dynStepSize)
  return setmetatable(o, vrep_position_controller)
end

function vrep_position_controller:update(...)
  -- Following data is handed over from V-REP:
  ------------------------------------------------------------------------------
  local init, revolute, cyclic, jointHandle, passCnt, totalPasses,
  currentPos, targetPos, errorValue, effort, dynStepSize, lowLimit,
  hightLimit, targetVel, maxForceTorque, velUpperLimit = ...

  local _, currentVel = simGetObjectFloatParameter(jointHandle, 2012)
  local _, position_p_gain = simGetObjectFloatParameter(jointHandle, 2002)
  local _, position_i_gain = simGetObjectFloatParameter(jointHandle, 2003)
  local _, position_d_gain = simGetObjectFloatParameter(jointHandle, 2004)

  -- Initialize position pid controller:
  ------------------------------------------------------------------------------
  if (init) then
    self.position_pid:reset()
    self.position_pid:set_time_step(dynStepSize)
    self.position_pid:set_output_limits(-MAX_VELOCITY, MAX_VELOCITY)
  end

  -- Update pid gains and position setpoint:
  ------------------------------------------------------------------------------
  self.position_pid:set_gains(
    POSITION_P_GAIN_FACTOR*position_p_gain,
    POSITION_I_GAIN_FACTOR*position_i_gain,
    POSITION_D_GAIN_FACTOR*position_d_gain
  )
  self.position_pid:set_setpoint(targetPos)

  -- Get velocity setpoint (limit velocity to prevent overshoot):
  ------------------------------------------------------------------------------
  local velocity_setpoint = self.position_pid:update(currentPos)
  velocity_setpoint = math.min(velocity_setpoint, math.abs(errorValue/dynStepSize))
  velocity_setpoint = math.max(velocity_setpoint,-math.abs(errorValue/dynStepSize))
  return MAX_FORCE, velocity_setpoint
end

return vrep_position_controller
