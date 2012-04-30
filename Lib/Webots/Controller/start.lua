-- Get Computer for Lib suffix
local computer = os.getenv('COMPUTER') or '';
if (string.find(computer, 'Darwin')) then
  -- MacOS X uses .dylib:
  package.cpath = './?.dylib;' .. package.cpath;
else
  package.cpath = './?.so;' .. package.cpath;
end

require('controller');

print("\nStarting Webots Lua controller...");

playerID = os.getenv('PLAYER_ID') + 0;
teamID = os.getenv('TEAM_ID') + 0;


--SJ: Team-specific test code running 
if teamID == 98 then
  print("Starting test_walk");
  dofile("Player/Test/test_walk_webots.lua");
elseif teamID == 99 then
  print("Starting test_vision");
  dofile("Player/Test/test_vision_webots.lua");
elseif teamID==22 then
  print('football')
  dofile("Player/Test/test_football.lua");
else


--Default
--  dofile("Player/Test/test_walk_webots.lua");
--  dofile("Player/Test/test_vision_webots.lua");
--  dofile("Player/Test/test_joints_webots.lua");
--  dofile("Player/Test/test_punch_webots_op.lua");
--  dofile("Player/Test/test_stretcher.lua")

--  dofile("Player/main.lua");

    dofile("Player/Test/test_main_webots.lua");
end

