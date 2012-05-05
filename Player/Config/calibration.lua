module(..., package.seeall);

---------------------------------------------
-- Automatically generated calibration data
---------------------------------------------
cal={}

--Initial values for each robots

cal["betty"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 0,
  armBias={0,0,0,0,0,0},
  pid = 0,
};

cal["linus"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 0,
  armBias={0,0,0,0,0,0},
  pid = 1, --NEW FIRMWARE
};

cal["lucy"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 0,
  armBias={0,0,0,0,0,0},
  pid = 1, --NEW FIRMWARE
};
cal["scarface"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 0,
  armBias={0,0,0,0,0,0},
  pid = 0,
};

----------------------------------------------------------------
-------------------------------------------------------------
--Default values (may not be needed)

cal["betty"].servoBias={0,0,2,-6,-1,0,0,0,-3,-1,10,0};
cal["betty"].footXComp = 0.010;
cal["betty"].footYComp = 0.002;
cal["betty"].kickXComp = 0.005;
cal["betty"].headPitchComp = 0.005;

cal["linus"].servoBias={3,1,2,1,1,-3,-8,3,-13,-4,1,-5};
cal["linus"].footXComp = 0.00;
cal["linus"].footYComp = 0.002;
cal["linus"].kickXComp = -0.005;
cal["linus"].headPitchComp = 0.005;

cal["lucy"].servoBias={1,-28,-207,108,-26,-15,-43,-51,110,35,84,-29};
cal["lucy"].footXComp = 0.002;
cal["lucy"].footYComp = 0.002;
cal["lucy"].kickXComp = -0.005;
cal["lucy"].headPitchComp = 0.00;
cal["lucy"].armBias = vector.new({0,-15,0,0,-3,0}) * math.pi/180;

cal["scarface"].servoBias={0,0,0,0,0,0,0,0,0,-9,-4,0};
cal["scarface"].footXComp = -0.005;
cal["scarface"].footYComp = 0.00;
cal["scarface"].kickXComp = -0.005;
cal["scarface"].headPitchComp = 0.00;

------------------------------------------------------------
--Auto-appended calibration settings
------------------------------------------------------------

-- Updated date: Mon Apr  9 07:28:15 2012
cal["betty"].servoBias={0,0,2,-6,-1,0,0,0,-3,-1,-3,0,};

-- Updated date: Sun Apr 15 20:46:52 2012
cal["linus"].servoBias={3,1,2,1,1,-3,-8,3,-13,-4,1,-5,};
cal["linus"].footXComp=-0.003;
cal["linus"].kickXComp=0.000;

-- Updated date: Tue Apr 17 01:23:40 2012
cal["lucy"].servoBias={1,10,-18,20,24,7,-43,-4,10,0,6,0,};
cal["lucy"].footXComp=-0.003;
cal["lucy"].kickXComp=0.005;

-- Updated date: Mon Apr 16 18:28:20 2012
cal["betty"].servoBias={0,0,2,-6,-1,0,0,3,-3,-1,-3,-2,};
cal["betty"].footXComp=0.006;
cal["betty"].kickXComp=0.005;

-- Updated date: Mon Apr 16 23:36:32 2012
cal["scarface"].servoBias={0,0,7,0,0,0,0,0,-7,-9,-4,0,};
cal["scarface"].footXComp=0.002;
cal["scarface"].kickXComp=0.000;

-- Updated date: Wed Apr 18 12:26:58 2012
cal["scarface"].servoBias={0,0,7,0,0,0,0,0,-7,-9,-4,0,};
cal["scarface"].footXComp=0.002;
cal["scarface"].kickXComp=0.005;

-- Updated date: Wed Apr 18 23:55:59 2012
cal["lucy"].servoBias={19,3,4,20,19,10,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

-- Updated date: Thu Apr 19 21:39:44 2012
cal["lucy"].servoBias={19,3,4,20,19,10,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

-- Updated date: Fri Apr 20 00:00:29 2012
cal["linus"].servoBias={3,1,2,1,1,-3,-8,3,-13,-4,1,-5,};
cal["linus"].footXComp=-0.003;
cal["linus"].kickXComp=0.000;

-- Updated date: Fri Apr 20 21:12:24 2012
cal["lucy"].servoBias={19,3,10,20,19,22,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

-- Updated date: Fri Apr 20 21:14:31 2012
cal["lucy"].servoBias={19,-22,10,20,19,-1,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

-- Updated date: Fri Apr 20 21:16:10 2012
cal["lucy"].servoBias={19,-22,10,20,19,-1,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

--AFTER LEG SWAP WITH LUCY
-- Updated date: Mon Apr 23 22:03:46 2012
cal["linus"].servoBias={3,1,43,1,-12,-17,-8,-5,-13,-4,1,-5,};
cal["linus"].footXComp=0.012;
cal["linus"].kickXComp=0.005;

-- Updated date: Sat May  5 09:56:25 2012
cal["linus"].servoBias={3,1,43,1,-14,-31,-8,-5,-13,-4,1,0,};
cal["linus"].footXComp=0.006;
cal["linus"].kickXComp=0.005;
