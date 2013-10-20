--------------------------------
-- Humanoid arm state machine
-- (c) 2013 Stephen McGill, Seung-Joon Yi
--------------------------------
-- Use the fsm module
local fsm = require'fsm'

-- Require the needed states
local bodyIdle = require'bodyIdle'
local bodyInit = require'bodyInit'

-- Instantiate a new state machine with an initial state
-- This will be returned to the user
local sm = fsm.new(bodyIdle,bodyInit)

local bodyTeleop = require'bodyTeleop'
local bodyFollow = require'bodyFollow'
local bodySideways = require'bodySideways'
local bodyStepOver = require'bodyStepOver'
local bodyStepPlan = require'bodyStepPlan'

sm:add_state(bodyTeleop)
sm:add_state(bodyFollow)
sm:add_state(bodySideways)
sm:add_state(bodyStepOver)
sm:add_state(bodyStepPlan)

-- Setup the transitions for this FSM
--
sm:set_transition( bodyIdle, 'init', bodyInit )
--
sm:set_transition( bodyInit,   'follow', bodyFollow )
sm:set_transition( bodyFollow, 'init',   bodyInit )
sm:set_transition( bodyFollow, 'done',   bodyInit )
--
sm:set_transition( bodyInit,   'teleop', bodyTeleop )
sm:set_transition( bodyTeleop, 'done',   bodyInit   )
sm:set_transition( bodyTeleop, 'init',   bodyInit   )
sm:set_transition( bodyTeleop, 'follow', bodyFollow )
--
sm:set_transition( bodyInit,   'sideways', bodySideways )
sm:set_transition( bodySideways, 'init',   bodyInit )
sm:set_transition( bodySideways, 'done',   bodyInit )

sm:set_transition( bodyInit,   'stepover', bodyStepOver )
sm:set_transition( bodyStepOver,   'done', bodyInit )

sm:set_transition( bodyInit,   'stepplan', bodyStepPlan )
sm:set_transition( bodyStepPlan,   'done', bodyInit )


--------------------------
-- Setup the FSM object --
--------------------------
local obj = {}
obj._NAME = ...
local util = require'util'
-- Simple IPC for remote state triggers
local simple_ipc = require'simple_ipc'
local evts = simple_ipc.new_subscriber(...,true)
local debug_str = util.color(obj._NAME..' Event:','green')
local special_evts = special_evts or {}
obj.entry = function()
  sm:entry()
end
obj.update = function()
  -- Check for out of process events in non-blocking fashion
  local event, has_more = evts:receive(true)
  if event then
    local debug_tbl = {debug_str,event}
    if has_more then
      extra = evts:receive(true)
      table.insert(debug_tbl,'Extra')
    end
    local special = special_evts[event]
    if special then
      special(extra)
      table.insert(debug_tbl,'Special!')
    end
    print(table.concat(debug_tbl,' '))
    sm:add_event(event)
  end
  sm:update()
end
obj.exit = function()
  sm:exit()
end

obj.sm = sm

return obj
