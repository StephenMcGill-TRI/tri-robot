%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% UPenn THOR Human-Robot Interface
%% Copyright 2013 Stephen McGill
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [] = setup_gui()
    warning off;
    global H_FIGURE;
    global CAMERA LIDAR BODY SLAM NETMON CONTROL HMAP DEBUGMON WAYPOINTS CURSOR

    %% Setup the main figure
    f = figure(1);
    H_FIGURE = gcf;
    clf;
    set(H_FIGURE, 'Name', 'UPenn DRC monitor', ...
        'NumberTitle', 'off', ...
        'tag', 'Colortable', ...
        'MenuBar', 'none', ...
        'ToolBar', 'figure', ...
        'Color', [.05 .1 .05], ...
        'Colormap', gray(256), ...
        'position',[1 1 800 450], ...
        'doublebuffer','off' );

    CONTROL = controlbody();
    WAYPOINTS = waypointbody();

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Head Camera
    
    HCAMERA_AXES = axes('Parent', H_FIGURE, ...
        'YDir', 'reverse','XTick', [],'YTick', [], 'Units', 'Normalized', ...
        'Position', [0.7 0.65 0.3 0.35]);

    CAMERA = camerabody();
    CAMERA.init(HCAMERA_AXES);
        

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    H_MESH_AXES = axes('Parent', H_FIGURE, ...
        'XTick', [], 'YTick', [], 'Units', 'Normalized', ...
        'Position', [0.05 0.25 0.5 0.5]);

    H_DMAP_AXES = axes('Parent', H_FIGURE, ...
        'XTick', [], 'YTick', [], 'Units', 'Normalized', ...
        'Position', [0.7 0.10 0.3 0.55]);

    % Robot visualization

    BODY = robotbody();
    BODY.init(H_MESH_AXES);

    rb1=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'View 1', 'Units', 'Normalized', ...
        'Position', [0 0.95 0.1 0.05] );

    rb2=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'View 2', 'Units', 'Normalized', ...
        'Position', [0.1 0.95 0.1 0.05] );

    rb3=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'View 3', 'Units', 'Normalized', ...
        'Position', [0.2 0.95 0.1 0.05] );

    rb4=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'View 4', 'Units', 'Normalized', ...
        'Position', [0.3 0.95 0.1 0.05] );
    rb5=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Show Robot', 'Units', 'Normalized', ...
        'Position', [0.4 0.95 0.1 0.05] );

    set(rb1,'CallBack',{BODY.set_viewpoint,1});
    set(rb2,'CallBack',{BODY.set_viewpoint,2});
    set(rb3,'CallBack',{BODY.set_viewpoint,3});
    set(rb4,'CallBack',{BODY.set_viewpoint,4});



    % 3d mesh controls
    LIDAR = lidarbody();
    LIDAR.init(H_DMAP_AXES,H_MESH_AXES);

%{
    lb1=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Head LIDAR', 'Units', 'Normalized', ...
        'Position', [0.6 0.95 0.1 0.05] );
    lb2=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Chest LIDAR', 'Units', 'Normalized', ...
        'Position', [0.6 0.9 0.1 0.05] );

    set(lb1,'CallBack',{LIDAR.set_meshtype,0});
    set(lb2,'CallBack',{LIDAR.set_meshtype,1});

%}

    sb1=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '2.5m', 'Units', 'Normalized', ...        
        'Position', [0.6 0.95 0.1 0.05] );    

    sb2=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '5m', 'Units', 'Normalized', ...        
        'Position', [0.6 0.90 0.1 0.05] );    

    sb3=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '10m', 'Units', 'Normalized', ...        
        'Position', [0.6 0.85 0.1 0.05] );    

    sb4=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '1X Pan', 'Units', 'Normalized', ...        
        'Position', [0.6 0.80 0.1 0.05] );    

    sb5=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '2X Pan', 'Units', 'Normalized', ...        
        'Position', [0.6 0.75 0.1 0.05] );    

    sb6=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '4X Pan', 'Units', 'Normalized', ...        
        'Position', [0.6 0.70 0.1 0.05] );    

    sb7=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Clear', 'Units', 'Normalized', ...        
        'Position', [0.6 0.05 0.1 0.1] );    


    

    set(sb1,'CallBack',{LIDAR.set_lidar_range,[.1 2.5]});
    set(sb2,'CallBack',{LIDAR.set_lidar_range,[.1 5]});
    set(sb3,'CallBack',{LIDAR.set_lidar_range,[.1 10]});

    set(sb4,'CallBack',{LIDAR.set_pan_speed,4});
    set(sb5,'CallBack',{LIDAR.set_pan_speed,2});
    set(sb6,'CallBack',{LIDAR.set_pan_speed,1});

    set(sb7,'CallBack',{WAYPOINTS.clear_waypoints});

    %depth map controls

%{
    lmb1 = uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '+', 'Units', 'Normalized', ...
        'Position', [THIRD_COL+0.00 SECOND_ROW-0.05 0.02 0.04]);

    lmb2 = uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '-', 'Units', 'Normalized', ...
        'Position', [THIRD_COL+0.02 SECOND_ROW-0.05 0.02 0.04]);

    lmb3 = uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Clear', 'Units', 'Normalized', ...
        'FontSize', 14, ...
        'Position', [THIRD_COL+0.00 SECOND_ROW-0.09 0.04 0.04]);
    % switch head <-> chest
    lmb4 = uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Chest', 'Units', 'Normalized', ...
        'FontSize', 14, ...
        'Position', [THIRD_COL+0.00 SECOND_ROW-0.12 0.04 0.04]);
    lmb5 = uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Acquire', 'Units', 'Normalized', ...
        'FontSize', 14, ...
        'Position', [THIRD_COL+0.00 SECOND_ROW-0.15 0.04 0.04]);

    set(lmb1,'CallBack',{LIDAR.set_zoomlevel,1});
    set(lmb2,'CallBack',{LIDAR.set_zoomlevel,2});
    set(lmb3,'CallBack',{LIDAR.clear_points});
    set(lmb4,'CallBack',{LIDAR.set_img_display});
    set(lmb5,'CallBack',{LIDAR.get_depth_img});

%}
   


%{    
    % SLAM image
    H_SLAM_AXES = axes('Parent', H_FIGURE, ...
        'XDir','reverse', 'XTick', [], 'YTick', [],'Units', 'Normalized', ...
        'Position', [FIRST_COL SECOND_ROW FIRST_COL_W SECOND_ROW_H]);
    
    SLAM = slambody();
    SLAM.init( H_SLAM_AXES);
    
    sb1=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '+', 'Units', 'Normalized', ...
        'Position', [SECOND_COL-0.05 SECOND_ROW-0.05 0.02 0.04]);
    
    sb2=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', '-', 'Units', 'Normalized', ...
        'Position', [SECOND_COL-0.03 SECOND_ROW-0.05 0.02 0.04]);

    set(sb1,'CallBack',{SLAM.set_zoomlevel,1});
    set(sb2,'CallBack',{SLAM.set_zoomlevel,2});
  %}

    
  
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Network Status monitor
    
    NETMON = netmonbody();

    H_NETWORK_TEXT = uicontrol('Style','text','Units','Normalized',...
           'Position', [0.4 0.1 0.2 0.05] );        
    H_NETWORK_AXES = axes('Parent', H_FIGURE, ...
        'XTick', [], 'YTick', [], 'Units', 'Normalized', ...
        'Position', [0.4 0 0.2 0.1] );            
    H_DEBUG_TEXT = uicontrol('Style','text','Units','Normalized',...
        'Position', [0.6 0 0.1 0.05] );   
    NETMON.init(H_NETWORK_AXES,H_NETWORK_TEXT);
    
    DEBUGMON = debugbody();
    DEBUGMON.init(H_DEBUG_TEXT);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Body FSM control
    %%

    b1=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Init', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [0 0 0.1 0.05] );    
    b2=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Approach', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [0.1 0 0.1 0.05] );            
    b3=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Stepover', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [0.2 0 0.1 0.05] );            
    b4=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Navigate', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [0.3 0 0.1 0.05] );    

    set(b1,'CallBack',{CONTROL.body_control,'init'});   
    set(b2,'CallBack',{CONTROL.body_control,'approach'});    
    set(b3,'CallBack',{CONTROL.body_control,'stepover'});
    set(b4,'CallBack',{CONTROL.body_control,'navigate'});        

    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Head FSM control
    %%
    

%{

    h1=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Head Fixed', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [SECOND_COL+0.4 0.045 0.08 0.04]);
    
    h2=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Head Center', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [SECOND_COL+0.48 0.045 0.08 0.04]);
    
    h3=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Regular scan', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [SECOND_COL+0.4 0.005 0.08 0.04]);
    
    h4=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Lower scan', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [SECOND_COL+0.48 0.005 0.08 0.04]);
    
    set(h1,'CallBack',{CONTROL.head_control,'reset'});
    set(h2,'CallBack',{CONTROL.head_control,'center'});
    set(h3,'CallBack',{CONTROL.head_control,'tiltscan'});
    set(h4,'CallBack',{CONTROL.head_control,'stepscan'});
%}




 % Various calculations

    MODELS = models();

    lc1 = uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Wheel', 'Units', 'Normalized', ...
        'FontSize', 14, ...
        'Position', [0.8,0.05,0.1,0.05]);
    lc2 = uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Door', 'Units', 'Normalized', ...
        'FontSize', 14, ...
        'Position', [0.9,0.05,0.1,0.05]);
    set(lc1,'CallBack',MODELS.wheel_calc);
    set(lc2,'CallBack',MODELS.door_calc);

%{
    lc3 = uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Tool', 'Units', 'Normalized', ...
        'FontSize', 14, ...
        'Position', [THIRD_COL-0.05 SECOND_ROW_CAM-0.13 0.04 0.04]);

    lc4 = uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Step', 'Units', 'Normalized', ...
        'FontSize', 14, ...
        'Position', [THIRD_COL-0.05 SECOND_ROW_CAM-0.17 0.04 0.04]);
    set(lc3,'CallBack',MODELS.tool_calc);
    set(lc4,'CallBack',MODELS.step_calc);
%}
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Arm state machine control
    
    a1=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Init', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [0.7,0.05,0.1,0.05]);
    
    a2=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Ready', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [0.7,0,0.1,0.05]);

    a3=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Reset', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [0.8,0,0.1,0.05]);
    
    a4=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Grab', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [0.9,0,0.1,0.05]);

%{    
    a5=uicontrol('Parent', H_FIGURE, 'Style', 'pushbutton', ...
        'String', 'Teleop', ...
        'FontSize', 14, ...
        'Units', 'Normalized', ...
        'Position', [THIRD_COL+.1 ARM_CONTROL_ROW-0.12 0.05 0.06]);
%}  
        
    set(a1,'CallBack',{CONTROL.arm_control,'init'});
    set(a2,'CallBack',{CONTROL.arm_control,'ready'});
    set(a3,'CallBack',{CONTROL.arm_control,'reset'});
    set(a4,'CallBack',{CONTROL.arm_control,'grab'});
%    set(a5,'CallBack',{CONTROL.arm_control,'teleop'});
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %Drag handling
    CURSOR=[];
    CURSOR.button_alt= 0;

    CURSOR.button_alt_mesh= 0;
    CURSOR.button_alt_camera= 0;
    CURSOR.last_pos = get (gcf, 'CurrentPoint');
    CURSOR.movement = [0 0];

    function mouseMove(obj,evt)
        C = get (gcf, 'CurrentPoint');
        if CURSOR.button_alt==1             
            CURSOR.movement = C-CURSOR.last_pos;           
            cmv=CURSOR.movement            
        end
        CURSOR.last_pos = C;
    end    

    function mouseRelease(obj,evt)
        CURSOR.button_alt = 0;
        CURSOR.button_alt_mesh= 0;
        CURSOR.button_alt_camera= 0;
    end
    set(gcf, 'WindowButtonMotionFcn', @mouseMove);
    set(gcf, 'WindowButtonUpFcn',     @mouseRelease);
end
