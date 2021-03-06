function ret = lidarbody()
    global HEAD_LIDAR CHEST_LIDAR LIDAR H_FIGURE DEBUGMON POSE SLAM CONTROL WAYPOINTS
    global CURSOR
    LIDAR.init = @init;
    LIDAR.update = @update;
    LIDAR.set_meshtype = @set_meshtype;
    LIDAR.set_img_display = @set_img_display;
    LIDAR.get_depth_img = @get_depth_img;
    LIDAR.clear_points = @clear_points;
    LIDAR.set_zoomlevel = @set_zoomlevel;

    LIDAR.update_waypoints = @update_waypoints;    

    LIDAR.set_pan_speed=@set_pan_speed;
    LIDAR.set_lidar_range=@set_lidar_range;


    % Which mesh to display: 0-HEAD, 1-CHEST
    LIDAR.meshtype = 1; % Chest lidar default
    LIDAR.mesh_cnt = 0;

    % 0: Show head 1: Show chest
    LIDAR.depth_img_display = 1; %Chest lidar default
    % points draw on this handle
    LIDAR.clicked_points  = []; % 2d
    LIDAR.selected_points = []; % 3d
    LIDAR.pointdraw = 0;

    %depth map size and zooming
    LIDAR.xsize = 0;
    LIDAR.ysize = 0;
    LIDAR.xmag =0;
    LIDAR.ymag =0;

    LIDAR.last_posxy = [];
    LIDAR.depth_range = [.1 5];


    wdim_mesh=361;
    hdim_mesh=60;

    HEAD_LIDAR=[];
    %SJ: DOUBLE CHECK THOSE VALUES, THEY ARE TOTALLY OFF!!
    HEAD_LIDAR.off_axis_height = 0.01; % 1cm off axis
    HEAD_LIDAR.neck_height = 0.30;

    %%%%% THEY ARE WEBOTS VALUES
    %HEAD_LIDAR.off_axis_height = 0.10; % 1cm off axis
    %HEAD_LIDAR.neck_height = 0.331; %based on webots


    %%%%for whatever reason, correct values does not work
    HEAD_LIDAR.off_axis_height = 0.01;
    HEAD_LIDAR.neck_height = 0.331; %based on webots



    HEAD_LIDAR.type = 0;
    HEAD_LIDAR.ranges=zeros(wdim_mesh,hdim_mesh);
    HEAD_LIDAR.range_actual=ones(wdim_mesh,hdim_mesh);

    HEAD_LIDAR.lidarangles={};
    HEAD_LIDAR.spineangles=[];
    HEAD_LIDAR.verts=[];
    HEAD_LIDAR.faces=[];
    HEAD_LIDAR.cdatas=[];
    HEAD_LIDAR.lidarrange = 1;
    HEAD_LIDAR.selected_points =[];

    HEAD_LIDAR.posex=[];
    HEAD_LIDAR.posey=[];
    HEAD_LIDAR.posea=[];


    CHEST_LIDAR=[];
    CHEST_LIDAR.off_axis_depth = 0.05;
    CHEST_LIDAR.chest_depth  = 0.05;
    CHEST_LIDAR.chest_height = 0.10;
    CHEST_LIDAR.type = 1;
    CHEST_LIDAR.ranges=zeros(wdim_mesh,hdim_mesh);
    CHEST_LIDAR.lidarangles={};
    CHEST_LIDAR.spineangles=[];
    CHEST_LIDAR.verts=[];
    CHEST_LIDAR.faces=[];
    CHEST_LIDAR.cdatas=[];
    CHEST_LIDAR.lidarrange = 1;

    CHEST_LIDAR.posex=[];
    CHEST_LIDAR.posey=[];
    CHEST_LIDAR.posea=[];

    function init(a_depth,a_mesh)
        %maximum size for 3d mesh
        
        %% Setup the image figure
        if a_depth~=0
            LIDAR.p_img = a_depth;
            axes(a_depth);
            % Default to head lidar
            LIDAR.h_img = imagesc( HEAD_LIDAR.ranges );
            set(LIDAR.p_img,'xtick',[],'ytick',[])
            colormap('JET')
            set(LIDAR.h_img, 'ButtonDownFcn', @select_3d );
            hold on;
            LIDAR.pointdraw = plot(a_depth,0,0,'g.');
            set(LIDAR.pointdraw, 'MarkerSize', 40 );
            hold off;
        end
        
        % Shared 3d mesh display
        LIDAR.p = a_mesh;
        if a_mesh~=0
            axes(a_mesh);
            LIDAR.h = patch('FaceColor','flat','EdgeColor','none',...
                'AmbientStrength',0.4,'SpecularStrength',0.9 );
            set(a_mesh,'xtick',[],'ytick',[], 'ztick',[])
            light('Position',[-3 1 3]);
            lighting flat            
            set(LIDAR.p, 'ButtonDownFcn', @button_down);
            set(LIDAR.h, 'ButtonDownFcn', @button_down);
      
            hold on;
              LIDAR.wayline = plot3(a_mesh,0,0,0,'g*-' );
              set(LIDAR.wayline,'XData',[]);
            hold off;
        end
    end

    function set_meshtype(~, ~, meshtype)
        LIDAR.meshtype = meshtype;
        % Only use chest lidar for mesh
        if meshtype == 1
          deg2rad = pi/180;
          CONTROL.send_control_packet([],[],...
              'vcm','chest_lidar','scanlines',[-45*deg2rad, 45*deg2rad, 1/deg2rad]);
          CONTROL.send_control_packet([],[],'vcm','chest_lidar','depths',[.1,5]);
          CONTROL.send_control_packet([],[],'vcm','chest_lidar','net',[2,2,95]);
          % LIDAR update rate: 40 Hz
        end

        update_mesh_display();
    end

    function update_mesh_display()
        if LIDAR.meshtype==0
            set(LIDAR.h,'Faces',HEAD_LIDAR.faces);
            set(LIDAR.h,'Vertices',HEAD_LIDAR.verts);
            set(LIDAR.h,'FaceVertexCData',HEAD_LIDAR.cdatas);
        else
            set(LIDAR.h,'Faces',CHEST_LIDAR.faces);
            set(LIDAR.h,'Vertices',CHEST_LIDAR.verts);
            set(LIDAR.h,'FaceVertexCData',CHEST_LIDAR.cdatas);
        end
    end

    function set_img_display(h,~,val)
        LIDAR.depth_img_display = 1-LIDAR.depth_img_display;
        if LIDAR.depth_img_display==0
            % Set the string to the next mesh (not current)
            set(h,'String','Chest');
        else
            set(h,'String','Head');
        end
        clear_points();
        draw_depth_image();
    end

    function get_depth_img(h,~)
        if LIDAR.depth_img_display==0
            % head
            CONTROL.send_control_packet([],[],'vcm','head_lidar','depths',[.1,2]);
            CONTROL.send_control_packet([],[],'vcm','head_lidar','net',[1,1,95,1]);
        else
            % chest
            CONTROL.chest_depth = true;
            CONTROL.send_control_packet([],[],'vcm','chest_lidar','depths',[.1,5]);
            %CONTROL.send_control_packet([],[],'vcm','chest_lidar','net',[1,1,95,1]);
            CONTROL.send_control_packet([],[],'vcm','chest_lidar','net',[2,1,95,1]);
        end
    end

    function set_lidar_range(h,~,range)
        CONTROL.send_control_packet([],[],'vcm','chest_lidar','depths',range);
        LIDAR.depth_range = range;
    end

    function set_pan_speed(h,~,panspeed)
        CONTROL.send_control_packet([],[],'vcm','chest_lidar','scanlines',...
            [-60*pi/180,60*pi/180,panspeed/(pi/180)]);        
%        CONTROL.send_control_packet([],[],'vcm','chest_lidar','net',[2,1,95,1]);
        CONTROL.send_control_packet([],[],'vcm','chest_lidar','net',[2,2,95,1]);
    end

    function draw_depth_image()
        % Draw the data       

        if LIDAR.depth_img_display==0
            set(LIDAR.h_img,'Cdata', HEAD_LIDAR.ranges);
            set(LIDAR.p_img, 'XLim', [1 size(HEAD_LIDAR.ranges,2)]);
            set(LIDAR.p_img, 'YLim', [1 size(HEAD_LIDAR.ranges,1)]);
        else
            %Chest lidar image is flipped horizontally
            set(LIDAR.h_img,'Cdata', fliplr(CHEST_LIDAR.ranges));
            set(LIDAR.p_img, 'XLim', [1 size(CHEST_LIDAR.ranges,2)]);
            set(LIDAR.p_img, 'YLim', [1 size(CHEST_LIDAR.ranges,1)]);
        end
    end
        
    function [nBytes] = update(fd)
        t0 = tic;
        nBytes = 0;
        while udp_recv('getQueueSize',fd) > 0
            udp_data = udp_recv('receive',fd);
            nBytes = nBytes + numel(udp_data);
        end

        [metadata,offset] = msgpack('unpack',udp_data);


        %SJ: metadata.depths is cell array with ubuntu
        if iscell(metadata.depths)
          metadata.depths = cell2mat(metadata.depths);
        end

        %disp(metadata)
        cdepth = udp_data(offset+1:end);
        if strncmp(char(metadata.c),'jpeg',3)==1
            depth_img = djpeg(cdepth);
        else
            depth_img = zlibUncompress(cdepth);
            depth_img = reshape(depth_img,[metadata.resolution(2) metadata.resolution(1)]);
            depth_img = depth_img'; %'
        end

        % Extract pose information 

        if isfield(metadata,'posex')
            %%THIS REQUIRES MESH_WIZARD2
            pose_data = [metadata.posex;metadata.posey;metadata.posez];
        else
            %temporarily using CURRENT pose for all lines instead (will result in mesh smearing)
            pose_data = POSE.pose'*ones(1,metadata.resolution(1));
        end
        
        % Calculate the angles (now support variable resolution for sensor)
        fov_angles = metadata.fov(1) : 1/metadata.reading_per_radian : metadata.fov(2);
        scanline_angles = metadata.scanlines(1) : 1/metadata.scanlines(3) : metadata.scanlines(2);
        
        if strncmp(char(metadata.name),'head',3)==1
            % Save data
            HEAD_LIDAR.ranges = depth_img;
            HEAD_LIDAR.fov_angles = fov_angles;
            HEAD_LIDAR.scanline_angles = scanline_angles;
            HEAD_LIDAR.depths = double(metadata.depths);
            HEAD_LIDAR.rpy = metadata.rpy;
            HEAD_LIDAR.poses = pose_data;
            % Update the figures
            draw_depth_image();
            update_mesh(0);
            update_mesh_display();
        else
            LIDAR.mesh_cnt = LIDAR.mesh_cnt + 1;
            % Save data
            CHEST_LIDAR.ranges = depth_img'; %'            
            CHEST_LIDAR.fov_angles = fov_angles;
            CHEST_LIDAR.scanline_angles = scanline_angles;
            CHEST_LIDAR.depths = double(metadata.depths);
            CHEST_LIDAR.rpy = metadata.rpy;
            CHEST_LIDAR.poses = pose_data;
            % Update depth image            
            draw_depth_image();
            % Update mesh image
            update_mesh(1);
            update_mesh_display();
        end
        
        % end of update
        tPassed = toc(t0);
        %fprintf('Update lidar: %f seconds.\n',tPassed);

    end


%%%TODO
    function set_zoomlevel(h_omap, ~, flags)
        if flags==1 %zoom in
            DEBUGMON.addtext('Zoom in');
            LIDAR.xmag = LIDAR.xsize/2*0.75;
            LIDAR.ymag = LIDAR.ysize/2*0.75;
            if numel(LIDAR.last_posxy)>0
                zoom_in(LIDAR.last_posxy);
            else
                zoom_in([LIDAR.xsize/2+1,LIDAR.ysize/2+1]);
            end
        else
            DEBUGMON.addtext('Zoom out');
            LIDAR.xmag = LIDAR.xsize/2;
            LIDAR.ymag = LIDAR.ysize/2;
            set(HEAD_LIDAR.p1, 'XLim', [1 LIDAR.xsize]);
            set(HEAD_LIDAR.p1, 'YLim', [1 LIDAR.ysize]);
            
        end
    end

    function zoom_in(posxy)
        if LIDAR.xsize>0
            LIDAR.last_posxy = posxy;
            xMin = posxy(1)-LIDAR.xmag;
            yMin = posxy(2)-LIDAR.ymag;
            xMax = posxy(1)+LIDAR.xmag;
            yMax = posxy(2)+LIDAR.ymag;
            set(HEAD_LIDAR.p1, 'XLim', [xMin xMax]);
            set(HEAD_LIDAR.p1, 'YLim', [yMin yMax]);
        end
    end

    function clear_points(h_omap, ~, flags)
        LIDAR.clicked_points  = []; % 2d
        LIDAR.selected_points = []; % 3d
        set(LIDAR.pointdraw,'XData',[]);
        set(LIDAR.pointdraw,'YData',[]);
        set(LIDAR.pointdraw,'MarkerSize',30);
        DEBUGMON.clearstr();
    end

    function targetpos = transform_global(relpos)
        %pose = POSE.pose_slam;
        pose = SLAM.slam_pose;
        targetpos=[];
        targetpos(1) =pose(1) + cos(pose(3)) * relpos(1) - sin(pose(3))*relpos(2);
        targetpos(2) =pose(2) + sin(pose(3)) * relpos(1) + cos(pose(3))*relpos(2);
        targetpos(3) = relpos(3);
        
        % Body Tilt
        ca = cos(SLAM.torso_tilt);
        sa = sin(SLAM.torso_tilt);
        targetpos(1) = targetpos(1)*ca + targetpos(3)*sa;
        targetpos(3) = -targetpos(1)*sa + targetpos(3)*ca;
    end

    function select_3d(~, ~, flags)        
        clicktype = get(H_FIGURE,'selectionType');
        if strcmp(clicktype,'alt')>0
            point = get(gca,'CurrentPoint');
            posxy = [point(1,1) point(1,2)];
            zoom_in(posxy);
            return;
        end
        
        % Add a circle point
        point = get(gca,'CurrentPoint');
        posxy = [point(1,1) point(1,2)];
        

        % Plot all the 2d points
        LIDAR.clicked_points = [LIDAR.clicked_points;posxy];
            set(LIDAR.pointdraw,'XData',LIDAR.clicked_points(:,1));
            set(LIDAR.pointdraw,'YData',LIDAR.clicked_points(:,2));
        
        % if head
        if LIDAR.depth_img_display==0
            % Round the index to an integer
            fov_angle_index = round( posxy(1) );
            scanline_index  = round( posxy(2) );
            % grab the range
            range = HEAD_LIDAR.ranges(scanline_index,fov_angle_index);
            range = double(range)/255 * (HEAD_LIDAR.depths(2)-HEAD_LIDAR.depths(1));
            range = range + HEAD_LIDAR.depths(1);
            fov_angle_selected = -1*HEAD_LIDAR.fov_angles(fov_angle_index);
            scanline_angle_selected = HEAD_LIDAR.scanline_angles(scanline_index);
            % TODO: Average nearby neighbor ranges
            % Convert the local coordinates to global
            local_point = [ ...
            range*cos(fov_angle_selected); ...
            range*sin(fov_angle_selected); ...
            HEAD_LIDAR.off_axis_height; ...
            0
            ];
            local_to_global = eye(4);
            local_to_global(1,1) = cos(scanline_angle_selected);
            local_to_global(3,3) = cos(scanline_angle_selected);
            local_to_global(1,3) = sin(scanline_angle_selected);
            local_to_global(3,1) = -sin(scanline_angle_selected);
            global_point = local_to_global * local_point;
            global_point(3) = global_point(3) + HEAD_LIDAR.neck_height;
            
        else           

            % Round the index to an integer
            fov_angle_index = round( posxy(2) );
            scanline_index  = round( posxy(1) );

            %SJ: Chest lidar depth image is flipped horizontally
            scanline_index  = size(CHEST_LIDAR.ranges,2) - scanline_index + 1;

            % grab the range
            range = CHEST_LIDAR.ranges(fov_angle_index,scanline_index);
            range = double(range)/255 * (CHEST_LIDAR.depths(2)-CHEST_LIDAR.depths(1));
            range = range + CHEST_LIDAR.depths(1);

            % Grab the correct angles
            fov_angle_selected = -1*CHEST_LIDAR.fov_angles(fov_angle_index);
            scanline_angle_selected = -1*CHEST_LIDAR.scanline_angles(scanline_index);
            
            %SJ: it is misleading as the selected point ls LOCAL from robot upper body frame
            global_point=chestproject(fov_angle_selected, scanline_angle_selected, range);

            %Get REAL global point (for navigation and etc)

            real_global_tr=...
                translate([POSE.pose(1);POSE.pose(2);POSE.body_height])*...
                rotZ(POSE.pose(3))*...
                rotY(CHEST_LIDAR.rpy(2))*...
                translate(global_point);
            real_global_point = real_global_tr(1:3,4)';   %'

        end % head/chest

        WAYPOINTS.add_waypoint(real_global_point(1:2));

        LIDAR.selected_points = [LIDAR.selected_points; global_point(1:3)']; %'


        LIDAR.selected_points
        disp_str = sprintf('Selected (%.3f %.3f %.3f)', ... 
            global_point(1),global_point(2),global_point(3) ); 
        disp(disp_str)
        DEBUGMON.addtext(disp_str);
    end % select_3d

    function select_3d_mesh()
        clicktype = get(H_FIGURE,'selectionType');        
        points = get(gca,'CurrentPoint'); % This returns two 3D points that is pependicular to the selected position
        %Calculate the intersection with the surface z=0
        k = points(2,3)/(points(2,3)-points(1,3));        
        point_intersect = points(1,1:2)*k + points(2,1:2)*(1-k);                
     %point_intersect %This is the new x-y position in GLOBAL coordinates
        point_intersect_local = pose_relative([point_intersect 0],POSE.pose)
        WAYPOINTS.add_waypoint(point_intersect(1:2));
    end

    function button_down(~,~,flags)
      clicktype = get(H_FIGURE,'selectionType');
      if strcmp(clicktype,'alt')>0
        CURSOR.button_alt_mesh = 1; %We use this for turning mesh around
      else
        select_3d_mesh();
      end
    end

    function update_waypoints(waypoints)    
        if size(waypoints,1)==0
            set( LIDAR.wayline, 'XData', [] );
            set( LIDAR.wayline, 'YData', [] );
            set( LIDAR.wayline, 'ZData', [] );            

            LIDAR.clicked_points = [];
            set(LIDAR.pointdraw,'XData',[]);
            set(LIDAR.pointdraw,'YData',[]);
            LIDAR.selected_points = [];
        else
            waypointsiz = size(waypoints)
            waypoints=[POSE.pose(1) POSE.pose(2);waypoints];        
            set( LIDAR.wayline, 'XData', waypoints(:,1) );
            set( LIDAR.wayline, 'YData', waypoints(:,2) );
            set( LIDAR.wayline, 'ZData', 0.1*ones(size(waypoints(:,1))));            
        end
    end

    function ret=chestproject(fov_angle, scanline_angle, range)
      x0 = cos(fov_angle)*range+CHEST_LIDAR.off_axis_depth;
      z0 = sin(fov_angle)*range; 
      cx = x0*cos(scanline_angle) + CHEST_LIDAR.chest_depth;
      cy = -x0*sin(scanline_angle);
      cz = z0 + CHEST_LIDAR.chest_height;
      ret = [cx;cy;cz];
    end

    function ret=pose_global(pRelative, pose)
      ca = cos(pose(3));
      sa = sin(pose(3));
      ret = [pose(1) + ca*pRelative(1)-sa*pRelative(2),...
            pose(2) + sa*pRelative(1)+ca*pRelative(2),...
            pose(3) + pRelative(3)];
    end

    function ret=pose_relative(pGlobal, pose)
      ca = cos(pose(3));
      sa = sin(pose(3));
      p = pGlobal-pose;
      ret=[ca*p(1)+sa*p(2) -sa*p(1)+ca*p(2) p(3)];
    end

    function ret = translate(pos)
       ret=[1 0 0 pos(1);0 1 0 pos(2);0 0 1 pos(3);0 0 0 1];
    end

    function ret = rotY(angle)
      ca=cos(angle); sa=sin(angle);
      ret = [ca 0 sa 0; 0 1 0 0; -sa 0 ca 0; 0 0 0 1];
    end

    function ret = rotZ(angle)
      ca=cos(angle); sa=sin(angle);
      ret = [ca -sa 0 0;sa ca 0 0; 0 0 1 0; 0 0 0 1];
  end

ret = LIDAR;
end
