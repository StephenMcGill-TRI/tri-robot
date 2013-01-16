module(... or '', package.seeall)

-- Add the required paths
cwd = '.';

uname  = io.popen('uname -s')
system = uname:read();

package.cpath = cwd.."/?.so;"..package.cpath;
package.cpath = cwd.."/../../Player/Lib/?.so;"..package.cpath;
package.path = cwd.."/../../Player/Util/?.lua;"..package.path;
package.path = cwd.."/../../Player/Config/?.lua;"..package.path;
package.path = cwd.."/../../Player/Vision/?.lua;"..package.path;

require('serialization');
require('util');
require('unix');
require('cutil');
require('rcm');
require('vector');

require 'torch'

-- Default values
local MAPS = {}
MAPS.res        = .2;
MAPS.invRes     = 1/MAPS.res;
MAPS.windowSize = 1; -- meters to see 
MAPS.edgeProx   = 2;
MAPS.xmin       = 0 - MAPS.windowSize;
MAPS.ymin       = 0 - MAPS.windowSize;
MAPS.xmax       = 0 + MAPS.windowSize;
MAPS.ymax       = 0 + MAPS.windowSize;
MAPS.zmin       = 0;
MAPS.zmax       = 5;
MAPS.sizex  = (MAPS.xmax - MAPS.xmin) / MAPS.res + 1;
MAPS.sizey  = (MAPS.ymax - MAPS.ymin) / MAPS.res + 1;

-- Occupancy Map
local OMAP = {}
OMAP.res        = MAPS.res;
OMAP.invRes     = MAPS.invRes;
OMAP.xmin       = MAPS.xmin;
OMAP.ymin       = MAPS.ymin;
OMAP.xmax       = MAPS.xmax;
OMAP.ymax       = MAPS.ymax;
OMAP.zmin       = MAPS.zmin;
OMAP.zmax       = MAPS.zmax;
OMAP.sizex  = MAPS.sizex;
OMAP.sizey  = MAPS.sizey;
--OMAP.storage = torch.ByteStorage(OMAP.sizex*OMAP.sizey)
--OMAP.data = torch.Tensor( OMAP.storage )
OMAP.data = torch.Tensor(OMAP.sizex,OMAP.sizex):zero()

OMAP.data = OMAP.data:copy( torch.ceil( torch.rand(OMAP.sizex,OMAP.sizex):mul(9) ) )

-- Helper Functions
require 'mapShift'

print(OMAP.data)
mapShift( OMAP, 5*OMAP.res, 5*OMAP.res )
print(OMAP.data)

require 'processL0'
processL0()

