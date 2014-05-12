--------------------------------
-- Motion Communication Module
-- (c) 2013 Stephen McGill, Seung-Joon Yi
--------------------------------
local memory = require'memory'
local vector = require'vector'

-- shared properties
local shared = {}
local shsize = {}

--Leg bias info
shared.leg={}
shared.leg.bias=vector.zeros(12)


-- Storing current stance info
shared.stance = {}
shared.stance.bodyTilt   = vector.zeros(1)
shared.stance.bodyHeight = vector.zeros(1)
shared.stance.bodyHeightTarget = vector.zeros(1)
shared.stance.uTorsoComp = vector.zeros(2) --For quasi-static balancing
shared.stance.uTorsoCompBias = vector.zeros(2)

shared.stance.waistPitchBias = vector.zeros(1) --To cancel out body sag
shared.stance.waistPitchBiasTarget = vector.zeros(1) --To cancel out body sag


--Used for drilling task
--Torso compensation is used to follow arm position, not for balancing
--0: compensation
--1: follow the arm
--2: stop compensation (keep current value)
shared.stance.enable_torso_track = vector.zeros(1)
shared.stance.track_hand_isleft = vector.zeros(1)
shared.stance.track_hand_y0 =  vector.zeros(1)
shared.stance.track_torso_y0 =  vector.zeros(1)

--Arm info

shared.arm = {}

--Target arm position (w/o compensation)
shared.arm.qlarm = vector.zeros(7)
shared.arm.qrarm = vector.zeros(7)

--Torso-Compensated arm position
shared.arm.qlarmcomp = vector.zeros(7)
shared.arm.qrarmcomp = vector.zeros(7)

--Current arm velocity limit
shared.arm.dqVelLeft = vector.zeros(6) --linear vel
shared.arm.dpVelLeft = vector.zeros(7) --joint vel

shared.arm.dqVelRight = vector.zeros(6)
shared.arm.dpVelRight = vector.zeros(7)

--hand offset X and Y (for hook)
if Config.arm then
  shared.arm.handoffset = vector.new(Config.arm.handoffset.gripper)
  shared.arm.lhandoffset = vector.new(Config.arm.handoffset.gripper)
  shared.arm.rhandoffset = vector.new(Config.arm.handoffset.gripper)
end

-- Walk Parameters
shared.walk = {}
shared.walk.bodyOffset = vector.zeros(3)
shared.walk.tStep      = vector.zeros(1)
shared.walk.bodyHeight = vector.zeros(1)
shared.walk.stepHeight = vector.zeros(1)
shared.walk.footY      = vector.zeros(1)
shared.walk.supportX   = vector.zeros(1)
shared.walk.supportY   = vector.zeros(1)
shared.walk.vel        = vector.zeros(3)
shared.walk.bipedal    = vector.zeros(1)
shared.walk.stoprequest= vector.zeros(1)
shared.walk.ismoving= vector.zeros(1)


-- Walk-step transition
shared.walk.steprequest= vector.zeros(1)
shared.walk.step_supportleg= vector.zeros(1)






-- Motion Status
shared.status = {}
shared.status.velocity   = vector.zeros(3)
shared.status.odometry   = vector.zeros(3)
shared.status.bodyOffset = vector.zeros(3)
shared.status.falling    = vector.zeros(1)

--Current Foot and Torso Poses
--TODO: extend to 6D poses
shared.status.uLeft = vector.zeros(3)
shared.status.uRight = vector.zeros(3)
shared.status.uTorso = vector.zeros(3)

--We store the torso velocity (to handle stopping)
shared.status.uTorsoVel = vector.zeros(3)

--ZMP is stored here for external monitoring
shared.status.uZMP = vector.zeros(3)

--If we are kneeling, we don't need quasistatic balancing
shared.status.iskneeling    = vector.zeros(1)

--If we are in wide stance, we don't use lateral quasistatic balancing 
shared.status.iswidestance    = vector.zeros(1)

--Current time
shared.status.t = vector.zeros(1)

-- Foot support
--SJ: they are bit misleading as they are different from 'support' positions
shared.support = {}
shared.support.uLeft_now   = vector.zeros(3)
shared.support.uRight_now  = vector.zeros(3)
shared.support.uTorso_now  = vector.zeros(3)
shared.support.uLeft_next  = vector.zeros(3)
shared.support.uRight_next = vector.zeros(3)
shared.support.uTorso_next = vector.zeros(3)




local maxSteps = 8
shared.step = {}

--Footsteps queue
--{[rx ry ra supportLeg t0 t1 t2 zmpmodx zmpmody zmpmoda stepparam1 stepparam2 stepparam3]}
shared.step.footholds  = vector.zeros(13*maxSteps)
shared.step.nfootholds = vector.zeros(1)







---------------
-- ADDED FOR NAO
---------------
--[[

shared.walk.bodyOffset = vector.zeros(3);
shared.walk.tStep = vector.zeros(1);
shared.walk.bodyHeight = vector.zeros(1);
shared.walk.bodyTilt = vector.zeros(1);
shared.walk.stepHeight = vector.zeros(1);
shared.walk.footY = vector.zeros(1);
shared.walk.supportX = vector.zeros(1);
shared.walk.supportY = vector.zeros(1);
shared.walk.uLeft = vector.zeros(3);
shared.walk.uRight = vector.zeros(3);
shared.walk.vel = vector.zeros(3);

--Robot specific calibration values
shared.walk.footXComp = vector.zeros(1);
shared.walk.kickXComp = vector.zeros(1);
shared.walk.headPitchBiasComp = vector.zeros(1);


-- How long have we been still for?
shared.walk.stillTime = vector.zeros(1);

-- Is the robot moving?
shared.walk.isMoving = vector.zeros(1);

--If the robot carries a ball, don't move arms
shared.walk.isCarrying = vector.zeros(1);
shared.walk.bodyCarryOffset = vector.zeros(3);

--To notify world to reset heading
shared.walk.isFallDown = vector.zeros(1);

--Is the robot spinning in bodySearch?
shared.walk.isSearching = vector.zeros(1);

--Is the robot doing the ZMP step kick?
shared.walk.isStepping = vector.zeros(1);


shared.us = {};
shared.us.left = vector.zeros(10);
shared.us.right = vector.zeros(10);
shared.us.obstacles = vector.zeros(2);
shared.us.free = vector.zeros(2);
shared.us.dSum = vector.zeros(2);
shared.us.distance = vector.zeros(2);

shared.motion = {};
--Should we perform fall check
shared.motion.fall_check = vector.zeros(1);

--]]
---------------
-- END ADDED FOR NAO
---------------






memory.init_shm_segment(..., shared, shsize)






---------------
-- ADDED FOR NAO
---------------
--[[
-- helper functions

---
--Get the distance moved in one step
--@param u0 The previous position
--@return The Distance moved with the current walk plan
--@return The global position of the planned step
function get_odometry(u0)
  if (not u0) then
    u0 = vector.new({0, 0, 0});
  end
  local uFoot = util.se2_interpolate(.5, get_walk_uLeft(), get_walk_uRight());
  return util.pose_relative(uFoot, u0), uFoot;
end

--Now those parameters are dynamically adjustable
local footX = Config.walk.footX or 0;
local kickX = Config.walk.kickX or 0;
local footXComp = Config.walk.footXComp or 0;
local kickXComp = Config.walk.kickXComp or 0;
local headPitchBias= Config.walk.headPitchBias or 0;
local headPitchBiasComp= Config.walk.headPitchBiasComp or 0;

mcm.set_walk_footXComp(footXComp);
mcm.set_walk_kickXComp(kickXComp);
mcm.set_walk_headPitchBiasComp(headPitchBiasComp);

function mcm.get_footX()
  return mcm.get_walk_footXComp() + footX;
end

function mcm.get_kickX()
  return mcm.get_walk_kickXComp();
end

function mcm.get_headPitchBias()
  return mcm.get_walk_headPitchBiasComp()+headPitchBias;
end
--]]
---------------
-- END ADDED FOR NAO
---------------
