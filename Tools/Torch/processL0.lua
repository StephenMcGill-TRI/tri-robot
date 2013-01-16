--
-- Lidar0 message handler (horizontal lidar)
--

function processL0()

  -- Convert from float to double, since lidar readings are floats
  ranges = rcm.get_lidar_ranges();
  -- Put lidar readings into relative cartesian coordinate
  xs = ranges:clone():cmul( LIDAR0.cosines );
  ys = ranges:clone():cmul( LIDAR0.sines );
  zs = ranges:clone():zero();

  -- TODO: DEBUG
  print(ranges)
  print(xs)
  print(zs)

  -- Accept only ranges that are sufficiently far away
  --dranges = [0; diff(ranges)];
  indGood = ranges:clone():zero();
  -- TODO: Make fast masking!
  for i=1,#ranges do
    --indGood[i] = ranges[i]>0.25 and LIDAR0.mask and abs(dranges)<0.1;
    indGood[i] = ranges[i]>0.25 and LIDAR0.mask
  end
  -- Select only the "good" readings
  xs:apply( domask(indGood) );
  ys:apply( domask(indGood) );
  ys:apply( domask(indGood) );

  -- Apply the transformation given current roll and pitch
  T = transpose(roty(IMU.data.pitch)*rotx(IMU.data.roll));
  --T = eye(4);
  --X = [xsg ysg zsg onesg];
  -- TODO: for memory efficiency, this Tensor should be 
  -- declared up top, and "views" should just be manipulated as
  -- xs, ys, zs.  Look at the memory allocation, so it's 
  -- just [<---xs---><---ys---><---zs--->]
  X = torch.Tensor(#ranges,4)
  X:select(2,1):copy(xs)
  X:select(2,2):copy(ys)
  X:select(2,3):copy(zs)
  X:select(2,4):fill(1);
  Y=torch.mm(X,T);  --reverse the order because of transpose

  -- Do not use the points that supposedly hit the ground (check!!)
  -- TODO: Make fast masking!
  zs = X:select(2,3);
  for i=1,#ranges do
    indGood[i] = zs[i]>-0.3
  end

  -- Separate coordinates in the sensor frame
  xsss = Y(indGood,1);
  ysss = Y(indGood,2);
  zsss = Y(indGood,3);
  onez = ones(size(xsss));

  -- These are now the default cartesian points
  LIDAR0.xs = xsss;
  LIDAR0.ys = ysss;

  --number of poses in each dimension to try

  --
  -- Begin the scan matching to update the SLAM pose
  --
  -- if encoders are zero, don't move
  -- if(SLAM.odomChanged > 0)
  if true then
    SLAM.odomChanged = 0;

    -- figure out how much to search over the yaw space based on the 
    -- instantaneous angular velocity from imu

    -- Perfrom the scan matching
    slamScanMatchPass1();
    slamScanMatchPass2();

    -- If no good fits, then use pure odometry readings
    if hmax < 500 then
      SLAM.x = SLAM.xOdom;
      SLAM.y = SLAM.yOdom;
      SLAM.yaw = SLAM.yawOdom;
    end

  else
    print('not moving');
  end

  -- Save pose data from SLAM to the 
  -- global POSE structure
  POSE.data.x     = SLAM.x;
  POSE.data.y     = SLAM.y;
  POSE.data.z     = SLAM.z;
  POSE.data.roll  = IMU.data.roll;
  POSE.data.pitch = IMU.data.pitch;
  POSE.data.yaw   = SLAM.yaw;
  POSE.data.t     = unix.time();
  POSE.t          = unix.time();
  SLAM.xOdom      = SLAM.x;
  SLAM.yOdom      = SLAM.y;
  SLAM.yawOdom    = SLAM.yaw;

  -- Log some data
  --[[
  if (POSES.log)
  POSES.cntr = POSES.cntr + 1;
  POSES.data(:,POSES.cntr) = [SLAM.x; SLAM.y; SLAM.z; IMU.data.roll; IMU.data.pitch; SLAM.yaw];
  POSES.ts(POSES.cntr) = LIDAR0.scan.startTime;
  end
  --]]

  --
  -- Update the map, since our pose was just updated
  --

  -- Take the laser scan points from the body frame and put them in the
  -- world frame
  tmp = torch.mm( trans( {SLAM.x, SLAM.y, SLAM.z} ), rotz(SLAM.yaw) )
  T = transpose( 
  torch.mm( 
  tmp, 
  trans( {LIDAR0.offsetx, LIDAR0.offsety, LIDAR0.offsetz}) 
  )
  )
  -- X = [xsss ysss zsss onez];
  -- TODO: for memory efficiency, this Tensor should be 
  -- declared up top, and "views" should just be manipulated as
  -- xs, ys, zs.  Look at the memory allocation, so it's 
  -- just [<---xs---><---ys---><---zs--->]
  X = torch.Tensor(#ranges,4)
  X:select(2,1):copy(xs)
  X:select(2,2):copy(ys)
  X:select(2,3):copy(zs)
  X:select(2,4):fill(1);
  Y=torch.mm(X,T);  --reverse the order because of transpose

  -- Separate cartesian coordinates
  xss = Y:select(2,1);
  yss = Y:select(2,2);

  -- Convert each cartesian point to a map index
  xis = ceil((xss - OMAP.xmin) * OMAP.invRes);
  yis = ceil((yss - OMAP.ymin) * OMAP.invRes);

  -- Only keep point whose indices lie within the map boundaries
  -- TODO
  --indGood = (xis > 1) & (yis > 1) & (xis < OMAP.map.sizex) & (yis < OMAP.map.sizey);
  --
  inds = sub2ind(size(OMAP.map.data),xis(indGood),yis(indGood));

  -- By how much should should we update the map
  -- at each index from a laser return?
  inc=5;
  if SLAM.lidar0Cntr == 1 then
    inc=100;
  end

  OMAP.map.data[inds] = OMAP.map.data(inds)+inc;
  DHMAP.map.data[inds] = 1;

  -- Decay the map around the robot
  if SLAM.lidar0Cntr%20 == 0 then
    -- Get the map indicies for the robot
    xiCenter = ceil((SLAM.x - OMAP.xmin) * OMAP.invRes);
    yiCenter = ceil((SLAM.y - OMAP.ymin) * OMAP.invRes);

    -- Amount of the surrounding to decay
    --windowSize = 30 *OMAP.invRes;
    windowSize = 10 * OMAP.invRes;
    -- Get the surrounding's extreme indicies
    ximin = ceil(xiCenter - windowSize/2);
    ximax = ximin + windowSize - 1;
    yimin = ceil(yiCenter - windowSize/2);
    yimax = yimin + windowSize - 1;

    -- Clamp if the surrounding exceeds the map boundaries
    if ximin < 1 then
      ximin = 1;
    end
    if ximax > OMAP.map.sizex then
      ximax = OMAP.map.sizex;
    end
    if yimin < 1 then
      yimin=1;
    end
    if yimax > OMAP.map.sizey then
      yimax= OMAP.map.sizey;
    end

    -- Perform the decay on the surreoundings
    localMap = OMAP.data:sub( ximin,ximax,  yimin,yimax );
    -- TODO
    --indd = localMap<50 & localMap > 0;
    --localMap(indd) = localMap(indd)*0.95;
    --localMap(localMap>100) = 100;
    --
    -- merge the small map back into the full map
    -- TODO
    --OMAP.data:sub( ximin,ximax,   yimin,yimax ) = localMap;

  end
  -- Finished the decay

  --
  -- Determine if we need to shift the map
  --

  -- Always shift by a standard amount
  shiftAmount = 10; --meters
  xShift = 0;
  yShift = 0;
  -- Check in which directions we need to shift
  if (SLAM.x - OMAP.xmin < MAPS.edgeProx) then xShift = -shiftAmount; end
  if (SLAM.y - OMAP.ymin < MAPS.edgeProx) then yShift = -shiftAmount; end
  if (OMAP.xmax - SLAM.x < MAPS.edgeProx) then xShift = shiftAmount; end
  if (OMAP.ymax - SLAM.y < MAPS.edgeProx) then yShift = shiftAmount; end

  -- Perform the shift via helper functions
  if xShift ~= 0 or yShift ~= 0 then
    OMAP  = mapResize(OMAP,xShift,yShift);
    ScanMatch2D('setBoundaries',OMAP.xmin,OMAP.ymin,OMAP.xmax,OMAP.ymax);
  end

  -- Set the last updated time
  LIDAR0.lastTime = LIDAR0.scan.startTime;

end
