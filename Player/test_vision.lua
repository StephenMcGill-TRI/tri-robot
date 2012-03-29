module(... or '', package.seeall)

-- Get Platform for package path
cwd = '.';
local platform = os.getenv('PLATFORM') or '';
if (string.find(platform,'webots')) then cwd = cwd .. '/Player';
end

-- Get Computer for Lib suffix
local computer = os.getenv('COMPUTER') or '';
if (string.find(computer, 'Darwin')) then
  -- MacOS X uses .dylib:
  package.cpath = cwd .. '/Lib/?.dylib;' .. package.cpath;
else
  package.cpath = cwd .. '/Lib/?.so;' .. package.cpath;
end

package.path = cwd .. '/?.lua;' .. package.path;
package.path = cwd .. '/Util/?.lua;' .. package.path;
package.path = cwd .. '/Config/?.lua;' .. package.path;
package.path = cwd .. '/Lib/?.lua;' .. package.path;
package.path = cwd .. '/Dev/?.lua;' .. package.path;
package.path = cwd .. '/Motion/?.lua;' .. package.path;
package.path = cwd .. '/Motion/keyframes/?.lua;' .. package.path;
package.path = cwd .. '/Motion/walk/?.lua;' .. package.path;
package.path = cwd .. '/Vision/?.lua;' .. package.path;
package.path = cwd .. '/World/?.lua;' .. package.path;

require('Config')
--Shut down wireless team message
Config.dev.team='TeamNull'; 

require('unix')
require('getch')
require('Broadcast')
require('Config')
require('shm')
require('vector')
require('mcm')
require('vcm')
require('wcm')
require('Speak')
require('Body')
require('Motion')

smindex = 0;

Motion.entry();
darwin = false;
webots = false;

-- Enable OP specific 
if(Config.platform.name == 'OP') then
  darwin = true;
  --SJ: OP specific initialization posing (to prevent twisting)
  Body.set_body_hardness(0.3);
  Body.set_actuator_command(Config.stance.initangle)
end

getch.enableblock(1);
unix.usleep(1E6*1.0);
Body.set_body_hardness(0);

--This is robot specific 
webots = false;
init = false;
calibrating = false;
ready = false;
if( webots or darwin) then
  ready = true;
end

--State variables
initToggle = true;
targetvel=vector.zeros(3);
headangle=vector.new({0,10*math.pi/180});
headsm_running=0;
bodysm_running=0;

local count = 0;
local ncount = 100;
local imagecount = 0;
local t0 = unix.time();
local tUpdate = t0;

-- Broadcast the images at a lower rate than other data
local maxFPS = 2;
local imgFPS = 1;
local maxPeriod = 1.0 / maxFPS;
local imgRate = math.max( math.floor( maxFPS / imgFPS ), 1);
local broadcast_enable=0;
local tLastBroadcast = Body.get_time();
local broadcast_count=0;
local imageCount=0;

function broadcast()
  local ncount=20;
  local t=Body.get_time();
  if t-tLastBroadcast<maxPeriod then return;end
  if broadcast_enable==0 then return;end
  broadcast_count = broadcast_count + 1;

  local tstart = unix.time();
  -- Always send non-image data
  Broadcast.update(broadcast_enable);
  if( broadcast_count % imgRate == 0 ) then
    Broadcast.update_img(broadcast_enable,imagecount);    
    imagecount = imagecount + 1;
  end
  tPassed = unix.time() - tstart;  -- Sleep in order to get the right FPS

--[[
  print("Broadcast time:",tPassed);
  -- Display our FPS and broadcast level
  if (broadcast_count % ncount == 0) then
    print('fps: '..(ncount / (tstart - tUpdate))..', Level: '..broadcast_enable );
  end
--]]
  tLastBroadcast=t;

end

function process_keyinput()
  --Robot specific head pitch bias
  headPitch = vcm.get_camera_pitchBias();

  local str=getch.get();
  if #str>0 then

    local byte=string.byte(str,1);
    -- Walk velocity setting
    if byte==string.byte("i") then	targetvel[1]=targetvel[1]+0.02;
    elseif byte==string.byte("j") then	targetvel[3]=targetvel[3]+0.1;
    elseif byte==string.byte("k") then	targetvel[1],targetvel[2],targetvel[3]=0,0,0;
    elseif byte==string.byte("l") then	targetvel[3]=targetvel[3]-0.1;
    elseif byte==string.byte(",") then	targetvel[1]=targetvel[1]-0.02;
    elseif byte==string.byte("h") then	targetvel[2]=targetvel[2]+0.02;
    elseif byte==string.byte(";") then	targetvel[2]=targetvel[2]-0.02;

    -- Move the head around
    elseif byte==string.byte("w") then
      headsm_running=0;headangle[2]=headangle[2]-5*math.pi/180;
    elseif byte==string.byte("a") then
      headsm_running=0;headangle[1]=headangle[1]+5*math.pi/180;
    elseif byte==string.byte("d") then
      headsm_running=0;headangle[1]=headangle[1]-5*math.pi/180;
    elseif byte==string.byte("x") then
      headsm_running=0;headangle[2]=headangle[2]+5*math.pi/180;
    elseif byte==string.byte("s") then
      headsm_running=0;headangle[1],headangle[2]=0,0;

    -- Head pitch fine tuning (for camera angle calibration)
    elseif byte==string.byte("e") then	
      headsm_running=0;headangle[2]=headangle[2]-1*math.pi/180;
    elseif byte==string.byte("c") then	
      headsm_running=0;headangle[2]=headangle[2]+1*math.pi/180;

    -- Camera angle bias fine tuning 
    elseif byte==string.byte("q") then	
      headsm_running=0;
      headPitch=vcm.get_camera_pitchBias()+math.pi/180;
      vcm.set_camera_pitchBias(headPitch);
      print("\nCamera pitch bias:",headPitch*180/math.pi);
    elseif byte==string.byte("z") then	
      headsm_running=0;
      headPitch=vcm.get_camera_pitchBias()-math.pi/180;
      vcm.set_camera_pitchBias(headPitch);
      print("\nCamera pitch bias:",headPitch*180/math.pi);
    -- Head FSM testing
    elseif byte==string.byte("1") then	
      headsm_running = 1-headsm_running;
      if (headsm_running == 1) then
        HeadFSM.sm:set_state('headScan');
    end

    elseif byte==string.byte("2") then	
    -- Camera transform testing
      headsm_running = 0;
      local ball = wcm.get_ball();
      local trackZ = Config.vision.ball_diameter/2; 
      -- TODO: Nao needs to add the camera select
      headangle = vector.zeros(2);
      headangle[1],headangle[2] = 
 	HeadTransform.ikineCam(ball.x,	ball.y, trackZ);
      headangle[2]=headangle[2]+headPitch; --this is substracted below
      print("Head Angles for looking directly at the ball:", 
	unpack(headangle*180/math.pi));

    elseif byte==string.byte("5") then
    --Turn on body SM
      headsm_running=1;
      bodysm_running=1;
      BodyFSM.sm:set_state('bodySearch');   
      HeadFSM.sm:set_state('headScan');
      walk.start();

    elseif byte==string.byte("g") then	--Broadcast selection
      local mymod = 4;
      broadcast_enable = (broadcast_enable+1)%mymod;
      print("\nBroadcast:", broadcast_enable);

    --Left kicks (for camera angle calibration)
    elseif byte==string.byte("3") then	
      kick.set_kick("kickForwardLeft");
      Motion.event("kick");
    elseif byte==string.byte("4") then	
      kick.set_kick("kickSideLeft");
      Motion.event("kick");
    elseif byte==string.byte("t") then
      walk.doWalkKickLeft();
    elseif byte==string.byte("y") then
      walk.doSideKickLeft();
    elseif byte==string.byte("7") then	
      headsm_running,bodysm_running=0,0;
      Motion.event("sit");
    elseif byte==string.byte("8") then	
      if walk.active then walk.stop();end
      bodysm_running=0;
      Motion.event("standup");
    elseif byte==string.byte("9") then	
      Motion.event("walk");
      walk.start();
    end
    walk.set_velocity(unpack(targetvel));
    if headsm_running == 0 then
      Body.set_head_command({headangle[1],headangle[2]-headPitch});
      print("\nHead Yaw Pitch:", unpack(headangle*180/math.pi))
    end
  end
end

-- main loop
count = 0;
lcount = 0;
tUpdate = unix.time();

function update()
  count = count + 1;
  --Update battery info
  wcm.set_robot_battery_level(Body.get_battery_level());

  if (not init)  then
    if (calibrating) then
      if (Body.calibrate(count)) then
        Speak.talk('Calibration done');
        calibrating = false;
        ready = true;
      end
    elseif (ready) then
      -- initialize state machines
      package.path = cwd..'/BodyFSM/'..Config.fsm.body[smindex+1]..'/?.lua;'..package.path;
      package.path = cwd..'/HeadFSM/'..Config.fsm.head[smindex+1]..'/?.lua;'..package.path;
      require('BodyFSM')
      require('HeadFSM')

      BodyFSM.entry();
      HeadFSM.entry();

      init = true;
    else
      if (count % 20 == 0) then
        if (Body.get_change_state() == 1) then
          Speak.talk('Calibrating');
          calibrating = true;
        end
      end
      -- toggle state indicator
      if (count % 100 == 0) then
        initToggle = not initToggle;
        if (initToggle) then
          Body.set_indicator_state({1,1,1}); 
        else
          Body.set_indicator_state({0,0,0});
        end
      end
    end
  else
    -- update state machines 
    Motion.update();
    Body.update();
    if headsm_running>0 then
      HeadFSM.update();
    end
    if bodysm_running>0 then
      BodyFSM.update();
    end
    broadcast();
  end
  local dcount = 50;
  if (count % 50 == 0) then
--    print('fps: '..(50 / (unix.time() - tUpdate)));
    tUpdate = unix.time();
    -- update battery indicator
    Body.set_indicator_batteryLevel(Body.get_battery_level());
  end
  
  -- check if the last update completed without errors
  lcount = lcount + 1;
  if (count ~= lcount) then
    print('count: '..count)
    print('lcount: '..lcount)
    Speak.talk('missed cycle');
    lcount = count;
  end
end

-- if using Webots simulator just run update
if (webots) then
  while (true) do
    -- update motion process
    update();
    io.stdout:flush();
  end
end

if( darwin ) then
  local tDelay = 0.005 * 1E6; -- Loop every 5ms
  while 1 do
    process_keyinput();
    unix.usleep(tDelay);
    update();
  end
end
