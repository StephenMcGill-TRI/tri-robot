require('dcm')
require('zmq')
require('cmsgpack')

vrep_comms_manager = {}

local context = nil
local time_socket = nil
local time_endpoint = 'tcp://127.0.0.1:12000'
local handles = {}

-- vrep joint names
local joint_name = {
  'l_hip_yaw', 'l_hip_roll', 'l_hip_pitch',
  'l_knee_pitch', 'l_ankle_pitch', 'l_ankle_roll',
  'r_hip_yaw', 'r_hip_roll', 'r_hip_pitch',
  'r_knee_pitch', 'r_ankle_pitch', 'r_ankle_roll',
}

-- vrep joint controllers (0 = impedance, 1 = position)
local joint_controller = {
  0, 0, 0,
  0, 0, 0,
  0, 0, 0,
  0, 0, 0,
}
--[[
local joint_controller = {
  1, 1, 1,
  1, 1, 1,
  1, 1, 1,
  1, 1, 1,
}
--]]

local function initialize_devices()
  -- intialize vrep devices
  handles.robot = simGetObjectHandle('torso')
  handles.gyro = simTubeOpen(0, 'gyroData'..simGetNameSuffix(nil), 1)
  handles.accel = simTubeOpen(0, 'accelerometerData'..simGetNameSuffix(nil), 1)
  handles.joint = {}
  for i = 1,#joint_name do
    handles.joint[i] = simGetObjectHandle(joint_name[i])
    if handles.joint[i] < 0 then
      print('Could not get handle for '..joint_name[i])
    end
    simSetJointInterval(handles.joint[i], true, {0, 0})
    local joint_id = simPackFloats{i}
    simAddObjectCustomData(handles.joint[i], 2030, joint_id, #joint_id)
    local controller = simPackFloats{joint_controller[i]}
    simAddObjectCustomData(handles.joint[i], 2040, controller, #controller)
  end
end

local function update_actuators()
  -- update joint parameters 
  local joint_enable = dcm:get_joint_enable()
  local joint_force = dcm:get_joint_force()
  local joint_position = dcm:get_joint_position()
  local joint_velocity = dcm:get_joint_velocity()
  local joint_position_p_gain = dcm:get_joint_position_p_gain()
  local joint_position_i_gain = dcm:get_joint_position_i_gain()
  local joint_position_d_gain = dcm:get_joint_position_d_gain()
  local joint_velocity_p_gain = dcm:get_joint_velocity_p_gain()

  for i = 1,#joint_name do
    local gains = simPackFloats{
      joint_position_p_gain[i],
      joint_position_i_gain[i],
      joint_position_d_gain[i],
      joint_velocity_p_gain[i],
    }
    simAddObjectCustomData(handles.joint[i], 2050, gains, #gains)
    simSetObjectIntParameter(handles.joint[i], 2000, joint_enable[i])
    simSetJointForce(handles.joint[i], joint_force[i])
    simSetJointTargetPosition(handles.joint[i], joint_position[i])
    simSetJointTargetVelocity(handles.joint[i], joint_velocity[i])
  end
end

local function update_sensors()
  -- update joint sensors
  for i = 1,#joint_name do
    local force = simJointGetForce(handles.joint[i])
    local position = simGetJointPosition(handles.joint[i])
    local _, velocity = simGetObjectFloatParameter(handles.joint[i], 2012)
    dcm:set_joint_force_sensor(force, i)
    dcm:set_joint_position_sensor(position, i)
    dcm:set_joint_velocity_sensor(velocity, i)
  end

  -- update ahrs sensors
  local euler_angles = simGetObjectOrientation(handles.robot, -1)
  dcm:set_ahrs(euler_angles, 'euler')
  
  local data = simTubeRead(handles.gyro)
  if (data) then
    floats = simUnpackFloats(data)
    dcm:set_ahrs(floats, 'gyro')
  end
  
  data = simTubeRead(handles.accel)
  if (data) then
    floats = simUnpackFloats(data)
    dcm:set_ahrs(floats, 'accel')
  end

  -- update force-torque readings
  -- dcm:set_force_torque(l_fts, 'l_foot')
  -- dcm:set_force_torque(r_fts, 'r_foot')
end

local function reset_simulator()
  simStopSimulation()
  simStartSimulation()
end

local function reset_simulator_physics()
  simResetDynamicObject(handles.robot)
end

local function set_simulator_torso_frame(frame)
  local pose = frame:get_pose()
  -- -1 means set absolute position/orientation
  simSetObjectPosition(handles.robot, -1, {pose[1], pose[2], pose[3]})
  simSetObjectOrientation(handles.robot, -1, {pose[4], pose[5], pose[6]})
end

local function set_simulator_torso_twist(twist)
end

function vrep_comms_manager.entry()
  -- initialize vrep devices
  initialize_devices()

  -- initialize shared memory
  dcm:set_joint_enable(1, 'all')
  dcm:set_joint_position_p_gain(1.0, 'all')
  dcm:set_joint_position_i_gain(0.5, 'all')
  dcm:set_joint_position_d_gain(0.03, 'all')
  dcm:set_joint_velocity_p_gain(0, 'all')
  dcm:set_joint_force(0, 'all')
  dcm:set_joint_position(0, 'all')
  dcm:set_joint_velocity(0, 'all')
  dcm:set_joint_force_sensor(0, 'all')
  dcm:set_joint_position_sensor(0, 'all')
  dcm:set_joint_velocity_sensor(0, 'all')

  -- initialize ipc
  context = zmq.init(1)
  time_socket = context:socket(zmq.PUB)
  time_socket:bind(time_endpoint)

  -- initialize sensor shared memory
  vrep_comms_manager.update()
end

function vrep_comms_manager.update()
  update_actuators()
  update_sensors()
  local msg = cmsgpack.pack{simGetSimulationTime(), simGetSimulationTimeStep()}
  time_socket:send('time'..msg)
end

function vrep_comms_manager.exit()
  time_socket:close()
  context:term()
end

return vrep_comms_manager
