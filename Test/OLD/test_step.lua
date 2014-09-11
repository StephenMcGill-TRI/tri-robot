cwd = cwd or os.getenv('PWD')
package.path = cwd.."/?.lua;"..package.path;
local init = require('init')

local Config = require('Config');
smindex = 0;
package.path = cwd..'/BodyFSM/'..Config.fsm.body[smindex+1]..'/?.lua;'..package.path;
package.path = cwd..'/HeadFSM/'..Config.fsm.head[smindex+1]..'/?.lua;'..package.path;

local shm = require('shm')
local Body = require('Body')
local vector = require('vector')
local getch = require('getch')
local Motion = require('Motion');
local walk = require('walk');
local dive = require('dive');
local Speak = require('Speak')
local util = require('util')
darwin = false;
webots = false;

local grip = require('grip')
local crawl = require('crawl')



-- Enable OP specific 
if(Config.platform.name == 'OP') then
  darwin = true;
end

-- Enable Webots specific
if (string.find(Config.platform.name,'Webots')) then
  webots = true;
end

getch.enableblock(1);
--unix.usleep(1E6*1.0);


-- initialize state machines
Motion.entry();
--Motion.event("standup");

Body.set_head_hardness({0.4,0.4});

controller.wb_robot_keyboard_enable(100);
-- main loop
count = 0;
vcmcount=0;
local t0=Body.get_time();
local last_update_time=t0;
local headangle=vector.new({0,10*math.pi/180});
local headsm_running=0;
local bodysm_running=0;
local last_vision_upfasfdsaasfgate_time=t0;
targetvel=vector.zeros(3);
t_update=2;

--Motion.fall_check=0;
--Motion.fall_check=1;
broadcast_enable=0;
ballcount,visioncount,imagecount=0,0,0;
hires_broadcast=0;

cameraparamcount=1;
broadcast_count=0;
buttontime=0;




--Hack for saffire
Body.set_lleg_command({0,0,0,0,0,0,0,0,0,0,0,0})


function process_keyinput()
  local str = controller.wb_robot_keyboard_get_key();
  if str>0 then
    byte = str;
	-- Webots only return captal letter number
	if byte>=65 and byte<=90 then
		byte = byte + 32;
	end

  -- Walk velocity setting
--	if byte==string.byte("i") then	targetvel[1]=targetvel[1]+0.02;
--	elseif byte==string.byte(",") then	targetvel[1]=targetvel[1]-0.02;

	if byte==string.byte("i") then	targetvel[1]=targetvel[1]+0.30;
	elseif byte==string.byte(",") then	targetvel[1]=targetvel[1]-0.30;


	elseif byte==string.byte("j") then	targetvel[3]=targetvel[3]+0.1;
	elseif byte==string.byte("k") then	targetvel[1],targetvel[2],targetvel[3]=0,0,0;
	elseif byte==string.byte("l") then	targetvel[3]=targetvel[3]-0.1;
	elseif byte==string.byte("h") then	targetvel[2]=targetvel[2]+0.02;
	elseif byte==string.byte(";") then	targetvel[2]=targetvel[2]-0.02;

--[[
	elseif byte==string.byte("1") then	
--		kick.set_kick("kickForwardLeft");
--		Motion.event("kick");
		Motion.event("align");

	elseif byte==string.byte("2") then	
		kick.set_kick("kickForwardRight");
		Motion.event("kick");
	elseif byte==string.byte("3") then	
		kick.set_kick("kickSideLeft");
		Motion.event("kick");
	elseif byte==string.byte("4") then	
		kick.set_kick("kickSideRight");
		Motion.event("kick");
        elseif byte==string.byte("5") then
                walk.doWalkKickLeft();
        elseif byte==string.byte("6") then
--                walk.doWalkKickRight();
                walk.doSideKickRight();

--]]
    elseif byte==string.byte("1") then 
      largestep.load_step_queue(1);
      Motion.event("step");
    elseif byte==string.byte("2") then 
      largestep.load_step_queue(2);
      Motion.event("step");
    elseif byte==string.byte("3") then 
      largestep.load_step_queue(3);
      Motion.event("step");
    elseif byte==string.byte("4") then 
      largestep.load_step_queue(4);
      Motion.event("step");
    elseif byte==string.byte("5") then 
      largestep.load_step_queue(5);
      Motion.event("step");
    elseif byte==string.byte("6") then 
      largestep.load_step_queue(6);
      Motion.event("step");
    elseif byte==string.byte("7") then 
      largestep.load_step_queue(7);
      Motion.event("step");



	elseif byte==string.byte("w") then
		Motion.event("diveready");

	elseif byte==string.byte("s") then
	        dive.set_dive("diveCenter");
		Motion.event("dive");

	elseif byte==string.byte("a") then
	        dive.set_dive("diveLeft");
		Motion.event("dive");

	elseif byte==string.byte("d") then
	        dive.set_dive("diveRight");
		Motion.event("dive");
--[[
	elseif byte==string.byte("z") then
		grip.throw=0;
		Motion.event("pickup");

	elseif byte==string.byte("x") then
		grip.throw=1;
		Motion.event("throw");
--]]
	elseif byte==string.byte("z") then
--[[
	    walk.upper_body_override(
		vector.new({0,8,0})*math.pi/180,
		vector.new({0,-8,0})*math.pi/180,
		vector.new({0,20,0})*math.pi/180);
--]]

	    walk.upper_body_override(
		vector.new({0,8,0})*math.pi/180,
		vector.new({0,-90,0})*math.pi/180,
		vector.new({0,20,0})*math.pi/180);


	elseif byte==string.byte("x") then
	    walk.upper_body_override_off();





	elseif byte==string.byte("c") then
	    walk.upper_body_override(
--		vector.new({150,8,0})*math.pi/180,
--		vector.new({150,-8,0})*math.pi/180,
		vector.new({0,90,0})*math.pi/180,
		vector.new({0,-8,0})*math.pi/180,
		vector.new({0,20,0})*math.pi/180);

	elseif byte==string.byte("v") then
	    walk.startMotion("hurray");



	elseif byte==string.byte(";") then	targetvel[2]=targetvel[2]-0.02;


	elseif byte==string.byte("7") then	Motion.event("sit");
	elseif byte==string.byte("8") then	
		if walk.active or crawl.active then 
--  		  walk.stop();
   		  Motion.walk_stop();
		end
		Motion.event("standup");
	
	elseif byte==string.byte("9") then	
		Motion.event("walk");
--		walk.start();
		Motion.walk_start();
	end
--	walk.set_velocity(unpack(targetvel));
	Motion.set_walk_velocity(unpack(targetvel));
        print("Command velocity:",unpack(walk.velCommand))

  end

end


--ATLAS SPECIFIC ARM INITIALIZATION
--Atlas prototype default arm 
qLArmDefault = math.pi/180*vector.new({90,30,0,0,0,0});
qRArmDefault = math.pi/180*vector.new({90,-30,0,0,0,0});
arm_init_t0 = Body.get_time();
arm_init_duration = 1.0;


function update()
  Body.set_syncread_enable(0); --read from only head servos

  -- Update the relevant engines
  Body.update();

  --Hack to initialize atlas arm
  tPassed= Body.get_time() - arm_init_t0;
  if tPassed < arm_init_duration and Config.platform.name=='WebotsAtlas' then
    ph = tPassed / arm_init_duration;
    Body.set_larm_command((1-ph)*qLArmDefault + Config.walk.qLArm*ph);
    Body.set_rarm_command((1-ph)*qRArmDefault + Config.walk.qRArm*ph);    
  else
    Motion.update();
  end
  
  -- Get a keypress
  process_keyinput();
end

local tDelay=0.002*1E6;
local ncount = 100;
local tUpdate = Body.get_time();

while 1 do
  count = count + 1;
  
  update();
  io.stdout:flush();
  -- Show FPS
--[[
  local t = Body.get_time();
  if(count==ncount) then
    local fps = ncount/(t-tUpdate);
    tUpdate = t;
    count = 1;
--    print(fps.." FPS")
  end
--]]
  --Wait until dcm has done reading/writing
--  unix.usleep(tDelay);

end