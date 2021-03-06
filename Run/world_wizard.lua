#!/usr/bin/env luajit
local ENABLE_NET = true
local ENABLE_LOG = false
---------------------------
-- World Manager --
-- (c) Stephen McGill 2014    --
---------------------------
dofile'../include.lua'
local Body = require('Body')
local lW = require'libWorld'
local si = require'simple_ipc'
local mp = require'msgpack.MessagePack'
local vector = require'vector'
local util = require'util'
-- Cache some functions
local get_time = Body.get_time
-- Subscribe to important messages
local vision_ch = si.new_subscriber'vision0'

-- Who to send to
local operator
--operator = Config.net.operator.wireless
operator = Config.net.operator.wired

local stream = Config.net.streams.world
local udp_ch = ENABLE_NET and stream and stream.udp and si.new_sender(operator, stream.udp)
local udp_wireless_ch = ENABLE_NET and stream and stream.udp and si.new_sender(Config.net.operator.wireless, stream.udp)
local world_ch = stream and stream.sub and si.new_publisher(stream.sub)

-- SHM
require'wcm'
require'mcm'
require'hcm'

-- Cleanly exit on Ctrl-C
local running = true

local uOdometry0, uOdometry
local t_send, send_interval = 0

vision_ch.callback = function(skt)
	local detections = skt:recv_all(true)
	--print('#detections', #detections)
	-- Only use the last vision detection
	local detection
	for k, d in ipairs(detections) do
		local detect = mp.unpack(d)
		--print('DETECTION', detect)
		if type(detect)=='table' then
			detection = detect
		end
	end

	-- Update localization based onodometry and vision
	--Should use the differential of odometry!
	local uOdometry = mcm.get_status_odometry()
	dOdometry = util.pose_relative(uOdometry, uOdometry0 or uOdometry)
	uOdometry0 = vector.copy(uOdometry)

	if detection then
		--util.ptable(detection)
		lW.update(dOdometry, detection)
	end

end

-- Timeout in milliseconds
local TIMEOUT = 1 / 30 * 1e3
local poller = si.wait_on_channels{vision_ch}
local npoll
local t0, t = get_time()
local debug_interval, t_debug = 1, t0

local function update()
	send_interval = 1 / hcm.get_monitor_fps()
	npoll = poller:poll(TIMEOUT)

	t = get_time()

	if npoll==0 then
		-- If no frames, then just update by odometry
		--Should use the differential of odometry!
		local uOdometry = mcm.get_status_odometry()
		dOdometry = util.pose_relative(uOdometry, uOdometry0 or uOdometry)
		uOdometry0 = vector.copy(uOdometry)
--[[
		print("ODOM UPDATE",unpack(uOdometry))
		local pose = wcm.get_robot_pose()
		print("pose",unpack(pose))
--]]
		lW.update(dOdometry)

	end
	-- Send localization info
	local metadata = {
		id = 'world',
		world = lW.send(),
	}
	--util.ptable(metadata.world)
	if world_ch then
		world_ch:send(mp.pack(metadata))
	end
	if ENABLE_NET and t-t_send > send_interval then
		if udp_ch then
				local ret, err = udp_ch:send(mp.pack(metadata))
				if err and Config.debug.world then print(ret, err) end
		end
		if udp_wireless_ch then
				local ret, err = udp_wireless_ch:send(mp.pack(metadata))
				if err and Config.debug.world then print(ret, err) end
		end
		t_send = t
	end

	--Print the local position of step
	if t-t_debug>debug_interval and Config.debug.wolrld then
		t_debug = t
		local step_pose = util.pose_relative(wcm.get_step_pose(), wcm.get_robot_pose())
		print(string.format('HURDLE: %.2f %.2f %.1f',
		step_pose[1], step_pose[2], step_pose[3]*RAD_TO_DEG))
	end

end

if ... and type(...)=='string' then
	TIMEOUT = 0
	return {entry=lW.entry, update=update, exit=lW.exit}
end

local signal = require'signal'
local function shutdown()
	running = false
end
signal.signal("SIGINT", shutdown)
signal.signal("SIGTERM", shutdown)


lW.entry()
while running do
	update()
	if t - t_debug > debug_interval then
		t_debug = t
		print(string.format('World | Uptime: %.2f sec, Mem: %d kB', t-t0, collectgarbage('count')))
		print('Pose:', vector.pose(wcm.get_robot_pose()))
	end
end
lW.exit()
