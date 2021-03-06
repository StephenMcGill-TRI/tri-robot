local detectCorner = {}
local ok, ffi = pcall(require, 'ffi')
local ImageProc = require'ImageProc'
local ImageProc2 = require'ImageProc.ffi2'
local T = require'Transform'
local vector = require'vector'
local util = require'util'
local function bboxB2A(bboxB, scaleB)
	return {
		scaleB * bboxB[1],
		scaleB * bboxB[2] + scaleB - 1,
		scaleB * bboxB[3],
		scaleB * bboxB[4] + scaleB - 1,
	}
end

local T_thr = 0.15;
local dist_threshold = Config.vision.corner.dist_threshold or 15;
local length_threshold = Config.vision.corner.min_length or 5;
local min_center_dist = Config.vision.corner.min_center_dist or 1.5;

local function get_min_dist_line(x1,y1,x2,y2,x,y)
  -- nearest point: k(x1,y1) + (1-k)(x2,y2)
  -- dist: k^2 ((x1-x2)^2+(y1-y2)^2) +
  --           2k ((x1-x2)(x2-x) + (y1-y2)+(y2-y))  + C
  k = -((x1-x2)*(x2-x) + (y1-y2)*(y2-y))/((x1-x2)^2+(y1-y2)^2);
  if k>T_thr and k<1-T_thr then
    clx = k*x1+(1-k)*x2;
    cly = k*y1+(1-k)*y2;
    dist = (clx-x)^2 + (cly-y)^2;
    return clx,cly,dist;
  else
   return 0,0,999;
  end
end


local function get_min_dist(line,i,j)
  xi1=line.endpoint[i][1];
  xi2=line.endpoint[i][2];
  yi1=line.endpoint[i][3];
  yi2=line.endpoint[i][4];

  xj1=line.endpoint[j][1];
  xj2=line.endpoint[j][2];
  yj1=line.endpoint[j][3];
  yj2=line.endpoint[j][4];

  --L shape detection
  dist11 = (xi1-xj1)*(xi1-xj1) + (yi1-yj1)*(yi1-yj1);
  dist12 = (xi1-xj2)*(xi1-xj2) + (yi1-yj2)*(yi1-yj2);
  dist21 = (xi2-xj1)*(xi2-xj1) + (yi2-yj1)*(yi2-yj1);
  dist22 = (xi2-xj2)*(xi2-xj2) + (yi2-yj2)*(yi2-yj2);

  --T shape detection

  --line i to j1
  xc_i_j1,yc_i_j1,disti_j1=get_min_dist_line(xi1,yi1,xi2,yi2,xj1,yj1);

  --line i to j2
  xc_i_j2,yc_i_j2,disti_j2=get_min_dist_line(xi1,yi1,xi2,yi2,xj2,yj2);

  --line j to i1
  xc_j_i1,yc_j_i1,distj_i1=get_min_dist_line(xj1,yj1,xj2,yj2,xi1,yi1);

  --line j to i2
  xc_j_i2,yc_j_i2,distj_i2=get_min_dist_line(xj1,yj1,xj2,yj2,xi2,yi2);

  mindist = math.min (dist11,dist12,dist21,dist22,
	disti_j1, disti_j2, distj_i1, distj_i2);

  if mindist==dist11 then
    return mindist,
	{(xi1+xj1)/2,(yi1+yj1)/2},	--corner position
	{xi2,yi2},			--other line endpoint 1
	{xj2,yj2},			--other line endpoint 2
	1;
  elseif mindist==dist12 then
    return mindist,
	{(xi1+xj2)/2,(yi1+yj2)/2},
	{xi2,yi2},			--other line endpoint 1
	{xj1,yj1},
	1;
  elseif mindist==dist21 then
    return mindist,
	{(xi2+xj1)/2,(yi2+yj1)/2},
	{xi1,yi1},			--other line endpoint 1
	{xj2,yj2},
	1;
  elseif mindist==dist22 then
    return mindist,
	{(xi2+xj2)/2,(yi2+yj2)/2},
	{xi1,yi1},			--other line endpoint 1
	{xj1,yj1},
	1;
  elseif mindist==disti_j1 then
    return mindist,
	{xc_i_j1,yc_i_j1},	--corner point
	{xi1,yi1},
	{xi2,yi2},
	2;
  elseif mindist==disti_j2 then
    return mindist,
	{xc_i_j2,yc_i_j2},	--corner point
	{xi1,yi1},
	{xi2,yi2},
	2;
  elseif mindist==distj_i1 then
    return mindist,
	{xc_j_i1,yc_j_i1},	--corner point
	{xj1,yj1},
	{xj2,yj2},
	2;
  else
    return mindist,
	{xc_j_i2,yc_j_i2},	--corner point
	{xj1,yj1},
	{xj2,yj2},
	2;
  end
end


local function get_line_length(line,i)
  xi1=line.endpoint[i][1];
  xi2=line.endpoint[i][2];
  yi1=line.endpoint[i][3];
  yi2=line.endpoint[i][4];
  return math.sqrt((xi1-xi2)^2+(yi1-yi2)^2);
end

function detectCorner.update(line)
  --TODO: test line detection
  corner = {};
  corner.detect = 0;

  if line.detect==0 or line.nLines<2 then
    return corner;
  end

  linepair={};
  linepaircount=0;
  linepairvc0={};
  linepairv10={};
  linepairv20={};
  linepairangle={}
  linepairdist={}
  linepairtype={}

  -- Check perpendicular lines
--  vcm.add_debug_message(string.format("\nCorner: total %d
--lines\n",line.nLines))
  for i=1,line.nLines-1 do
    for j=i+1,line.nLines do
      ang=math.abs(util.mod_angle(line.angle[i]-line.angle[j]));
     if math.abs(ang-math.pi/2)<20*math.pi/180 then
	--Check endpoint distances in labelB
	mindist, vc0, v10, v20, cornertype = get_min_dist(line,i,j);
       -- vcm.add_debug_message(string.format(
	--	"line %d-%d :angle %d mindist %d type %d\n",
--		i,j,ang*180/math.pi, mindist,cornertype));
     --  print('i is '..i..' j is '..j..' ang is '..ang*180/math.pi..' mindist is '..mindist..' type is '..cornertype);
    -- print('line length 1 is '..get_line_length(line,i)..'line length 2 is '..get_line_length(line,j)..'mind dist is '..mindist);
    	if mindist<dist_threshold and
	get_line_length(line,i)>length_threshold and
	get_line_length(line,j)>length_threshold then
  	  linepaircount=linepaircount+1;
  	  linepair[linepaircount]={i,j};
	  linepairvc0[linepaircount]=vc0;
	  linepairv10[linepaircount]=v10;
	  linepairv20[linepaircount]=v20;
	  linepairangle[linepaircount]=ang;
	  linepairdist[linepaircount]=mindist;
	  linepairtype[linepaircount]=cornertype;
        	end
       end
    end
  end

  if linepaircount==0 then
    return corner;
  end

  best_corner=1;
  min_corner_dist = 999;

  --Pick the closest corner
  for i=1,linepaircount do
    vc0=linepairvc0[i];
    vc = HeadTransform.coordinatesB({vc0[1],vc0[2]});
    vc = HeadTransform.projectGround(vc,0);
    corner_dist=vc[1]*vc[1]+vc[2]*vc[2];
    if min_corner_dist>corner_dist then
      min_corner_dist = corner_dist;
      best_corner=i;
    end
  end

  corner.linepair=linepair[best_corner]
  corner.type=linepairtype[best_corner];

  vc0=linepairvc0[best_corner];
  v10=linepairv10[best_corner];
  v20=linepairv20[best_corner];

  vc = HeadTransform.coordinatesB({vc0[1],vc0[2]});
  vc = HeadTransform.projectGround(vc,0);

  v1 = HeadTransform.coordinatesB({v10[1],v10[2]});
  v1 = HeadTransform.projectGround(v1,0);

  v2 = HeadTransform.coordinatesB({v20[1],v20[2]});
  v2 = HeadTransform.projectGround(v2,0);

  --position in labelB
  corner.vc0=vc0;
  corner.v10=v10;
  corner.v20=v20;

  --position in xy
  corner.v = vc;
  corner.v1 = v1;
  corner.v2 = v2;

  --Center circle rejection
  pose=wcm.get_robot_pose();
  cornerpos = util.pose_global(corner.v,pose);
  center_dist = math.sqrt(cornerpos[1]^2+cornerpos[2]^2);
  if center_dist < min_center_dist then
 --   vcm.add_debug_message(string.format(
   --  "Corner: center circle check fail at %.2f\n",center_dist))
    return corner;
  end

  --Distance filter on the corners
  enable_corner_distance_filter = Config.vision.enable_distance_filter or 1;
  if(enable_corner_distance_filter == 1) then
    corner_distance_filter_threshold = Config.vision.distance_filter_threshold or 3;
    d = math.sqrt((cornerpos[1]-pose[1])^2 + (cornerpos[2]-pose[2])^2);
    if(d > corner_distance_filter_threshold) then
      --vcm.add_debug_message("Corner too far away from the robot");
      return corner;
    end
  end

  if corner.type==1 then
     vcm.add_debug_message("L-corner detected\n");
  else
     vcm.add_debug_message("T-corner detected\n");
  end

  corner.detect = 1;
  return corner;
end

return detectCorner
