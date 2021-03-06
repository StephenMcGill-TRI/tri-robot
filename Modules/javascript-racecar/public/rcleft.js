const port = 9001;
const ws =
    new window.WebSocket('ws://' + window.location.hostname + ':' + port);
ws.binaryType = 'arraybuffer';
const min = Math.min, max = Math.max, floor = Math.floor;
const to_jet = (v, a) => {
  // v is from 0 to 1
  // out is from 0 to 1
  // const fourValue = 4 * (1 - v);
  const fourValue = 4 * v;
  return "rgba(" +
         [
           floor(255 * min(fourValue - 1.5, 4.5 - fourValue)),
           floor(255 * min(fourValue - 0.5, 3.5 - fourValue)),
           floor(255 * min(fourValue + 0.5, 2.5 - fourValue)), a
         ].join() +
         ")";
};

const to_jet0 = (v) => {
  // v is from 0 to 1
  // out is from 0 to 1
  const fourValue = 4 * (1 - v);
  // const fourValue = 4 * v;
  return "rgb(" +
         [
           floor(255 * min(fourValue - 1.5, 4.5 - fourValue)),
           floor(255 * min(fourValue - 0.5, 3.5 - fourValue)),
           floor(255 * min(fourValue + 0.5, 2.5 - fourValue))
         ].join() +
         ")";
};

const to_heat0 = (v) => {
  // v is from 0 to 1
  // out is from 0 to 1
  // const fourValue = 4 * (1 - v);
  const fourValue = 4 * v;
  return [
    "rgb(", floor(255 * min(fourValue - 1.5, 4.5 - fourValue)),
    floor(255 * min(fourValue - 0.5, 3.5 - fourValue)),
    floor(255 * min(fourValue + 0.5, 2.5 - fourValue)), ")"
  ].join();
};

const RAD_TO_DEG = 180 / Math.PI;
const eps = 1e-4;

const to_rainbow =
    (v, a) => { return 'hsla(' + floor(360 * v) + ', 100%, 50%, ' + a + ')'; };

const n_timesteps = 75; // 100; // 75; // 100;
var risk_over_time = [], risk_times = [];
var gap_over_time = [];
var dj_over_time = [];

document.addEventListener("DOMContentLoaded", function(event) {
  var cur = {};

  const munpack = msgpack5().decode;
  /*
  const mpack = msgpack5().encode;
  const MAXIMUM_HEADER_LENGTH = 300;
  const LCM_PUBLISH_BUFFER_SIZE = 8192;
  var msg = new Uint8Array(LCM_PUBLISH_BUFFER_SIZE);
  var sequence_id = new Uint32Array(1);
  var ch = 'houston';
  msg.set([ 0x4c, 0x43, 0x30, 0x32 ]); // MAGIC_LCM2
  msg.set(sequence_id, 4);
  msg.set(Uint8Array.from(ch), 8);
  msg.set(mpack({"evt" : 'go'}), ch.length + 8);

  document.getElementById('go').addEventListener('click', () => {
    msg.set(sequence_id, 4);
    msg.set(Uint8Array.from(ch), 8);
    msg.set(mpack({"evt" : 'go'}), ch.length + 8);
    console.log(msg);
    ws.send(msg);
    sequence_id[0]++;
  });
  document.getElementById('stop').addEventListener('click', () => {
    var msg = new Uint8Array(
        [ MAGIC_LCM2, sequence_id, 'houston', mpack({"evt" : 'go'}) ]);
    ws.send(msg);
  });
  */

  // const d3colors = Plotly.d3.scale.category10();
  const d3colors = Plotly.d3.scale.category20();

  var likelihood_selection = 'beliefs';

  // Identifying the SVG size
  const environment_svg = document.getElementById('environment');
  var viewBox = environment_svg.getAttribute('viewBox').split(" ");
  var X_SVG_MIN = parseFloat(viewBox[0]), Y_SVG_MIN = parseFloat(viewBox[1]),
      X_SVG_SZ = parseFloat(viewBox[2]), Y_SVG_SZ = parseFloat(viewBox[3]);

  // Sizing the canvas
  // TODO: Recompute on resize
  const graph_canvas = document.getElementById('stage');
  var graph_ctx;
  var X_CANVAS_SZ, Y_CANVAS_SZ;
  const X_CANVAS_MIN = 0, Y_CANVAS_MIN = 0;
  var canvas_ready = false;
  const update_canvas = () => {
    const rect = environment_svg.getBoundingClientRect();
    X_CANVAS_SZ = graph_canvas.width = rect.width;
    Y_CANVAS_SZ = graph_canvas.height = rect.height;
    graph_ctx = graph_canvas.getContext('2d');
    // X_CANVAS_SZ = parseInt(graph_canvas.getAttribute('width'));
    // Y_CANVAS_SZ = parseInt(graph_canvas.getAttribute('height'));
    canvas_ready = true;
  };
  update_canvas();

  window.addEventListener('resize', () => {
    if (canvas_ready) {
      canvas_ready = false;
      window.requestAnimationFrame(update_canvas);
    }
  });

  const svg2canvas_sz = (s) => {
    return [ s[0] * X_CANVAS_SZ / X_SVG_SZ, s[1] * Y_CANVAS_SZ / Y_SVG_SZ ];
  };
  const svg2canvas = (p) => {
    return [
      X_CANVAS_SZ * (p[0] - X_SVG_MIN) / X_SVG_SZ + X_CANVAS_MIN,
      Y_CANVAS_SZ * (p[1] - Y_SVG_MIN) / Y_SVG_SZ + Y_CANVAS_MIN, p[2]
    ];
  };
  // const coord2svg = (p) => { return [ p[0], -p[1], -p[2] ]; };
  // Flip X and Y
  const coord2svg = (p) => { return [ p[1], p[0], Math.PI / 2 - p[2] ]; };

  const observer_svg = document.getElementById('observers');
  const vehicles_svg = document.getElementById('vehicles');
  const obstacles_svg = document.getElementById('obstacles');
  const lanes_svg = document.getElementById('lanes');
  const info_div = document.getElementById('info');
  const graph_div = document.getElementById('graph');
  const three_div = document.getElementById('three');

  //////////////////////////////////////////////////////
  // 3D Visualizations
  var rect = three_div.getBoundingClientRect();
  const THREE_CANVAS_WIDTH = rect.width;
  const THREE_CANVAS_HEIGHT = rect.height;

  var scene = new THREE.Scene();

  let plane = new THREE.Mesh(
      new THREE.PlaneBufferGeometry(X_SVG_SZ, Y_SVG_SZ),
      new THREE.MeshBasicMaterial({color : 0x808080, side : THREE.DoubleSide}));
  scene.add(plane);

  const sz_box_path = 0.05, sz_box_width = 0.05;
  const bel_mesh = new THREE.Mesh(
      new THREE.BoxBufferGeometry(sz_box_path, sz_box_width, sz_box_width),
      new THREE.MeshNormalMaterial());
  const risk_mesh = new THREE.Mesh(
      new THREE.BoxBufferGeometry(sz_box_path, sz_box_width, sz_box_width),
      new THREE.MeshNormalMaterial());
  // let risk_mesh =
  //     new THREE.Mesh(new THREE.CylinderBufferGeometry(
  //                        sz_box_width / 2, sz_box_width / 2, sz_box_width),
  //                    new THREE.MeshNormalMaterial());
  // risk_mesh.rotation.x = Math.PI / 2;
  const veh_mesh = new THREE.Mesh(
      new THREE.BoxBufferGeometry(0.45, 0.125, 0.125),
      new THREE.MeshLambertMaterial(
          {color : 0x000000, transparent : true, opacity : 0.5}));
  let observer_mesh =
      new THREE.Mesh(new THREE.BoxBufferGeometry(0.45, 0.125, 0.125),
                     new THREE.MeshLambertMaterial({color : 0x80FF80}));
  scene.add(observer_mesh);

  let bel_boxes = [];
  let risk_boxes = [];
  let veh_boxes = [];

  var renderer = new THREE.WebGLRenderer({antialias : true}); // try false
  // renderer.setClearColor(0x80CCFF, 1);
  renderer.setClearColor(0xFFFFFF, 1);
  renderer.setSize(THREE_CANVAS_WIDTH, THREE_CANVAS_HEIGHT);
  three_div.appendChild(renderer.domElement);

  let camera = new THREE.PerspectiveCamera(
      // 70, THREE_CANVAS_WIDTH / THREE_CANVAS_HEIGHT, 0.01, 5.5);
      // 50, THREE_CANVAS_WIDTH / THREE_CANVAS_HEIGHT, 0.01, 5.5);
      40, THREE_CANVAS_WIDTH / THREE_CANVAS_HEIGHT, 0.01, 5.5);
  camera.up.set(0, 0, 1);
  // Left turn sim
  // camera.position.set(X_SVG_SZ / 16, Y_SVG_MIN + 1 * Y_SVG_SZ / 4, 1);
  // camera.lookAt(0.5, 0, 0);
  // Roundabout turn sim
  // camera.position.set(X_SVG_MIN - 4 * X_SVG_SZ / 32, Y_SVG_MIN + Y_SVG_SZ /
  // 2,
  //                     1);
  // camera.lookAt(0, -1, 0);
  // Merge sim
  // camera.position.set(X_SVG_MIN + 0 * X_SVG_SZ / 32, Y_SVG_MIN + Y_SVG_SZ /
  // 6,
  //                     1);
  // camera.lookAt(-1, -1, 0);
  // Left turn RC
  // camera.position.set(X_SVG_MIN + 0 * X_SVG_SZ / 2,
  //                     Y_SVG_MIN + 3 * Y_SVG_SZ / 4, 1.25);
  // camera.lookAt(1, 1, 0);

  // New Holodeck (IROS)
  // TODO: Based on the message from LCM
  // Roundabout
  // camera.position.set(-1, 2.5, 1.25);
  // camera.lookAt(4 - 1.5, 2.5, 0);
  // Merge
  // camera.position.set(-0.5, 2.0, 1.25);
  // camera.lookAt(2.5, 3.25, 0);
  // Left turn
  camera.position.set(-1, 2.5, 1.75);
  camera.lookAt(1.25, 2.5, 0);

  var light0 = new THREE.AmbientLight(0x404040); // soft white light
  scene.add(light0);

  var light = new THREE.HemisphereLight(0xffffbb, 0x080820, 1);
  // var light = new THREE.HemisphereLight(0xffffbb, 0x808080);
  scene.add(light);

  function animate() {
    requestAnimationFrame(animate);
    renderer.render(scene, camera);
  }
  animate();
  //////////////////////////////////////////////////////

  var length = 12, width = 8;

  // let has_road = false;
  const update_road = (msg) => {
    // if (has_road) {
    //   return;
    // }
    const lanes = msg.paths;
    if (!lanes) {
      return;
    }
    const pt_to_pair =
        (coord, i) => { return coord2svg(coord).slice(0, 2).join(); };
    // Grab the SVG of each lane
    var lanes_els = lanes_svg.getElementsByClassName('lane');
    // console.log(lanes_els);
    // Iterate the names of the lanes
    Object.keys(lanes).forEach((name, ilane) => {
      const l = lanes[name];
      // console.log(name, l);
      // console.log("l['points']", l['points']);
      const points = l['points'].map(pt_to_pair).join(' ');
      const lane_id = 'lane_' + name;
      var el = lanes_els.namedItem(lane_id);
      if (!el) {
        el = document.createElementNS("http://www.w3.org/2000/svg", 'polyline');
        el.setAttributeNS(null, 'id', lane_id);
        el.setAttributeNS(null, 'class', 'lane');
        el.style.fill = "none";
        // el.style.stroke = "#0F0";
        el.style.stroke = d3colors(ilane);
        el.style.strokeWidth = "0.1";
        el.style.opacity = "0.3";
        // el.setAttributeNS(null, 'marker-start', 'url(#arrow)');
        el.setAttributeNS(null, 'marker-end', 'url(#marker-arrow)');
        if (name.startsWith('turn_')) {
          el.setAttributeNS(null, 'marker-mid', 'url(#marker-dot)');
        }
        lanes_svg.appendChild(el);
      }
      el.setAttributeNS(null, 'points', points);
    });

    // // Road shape
    // const lane_width = 0.1, lane_height = 0.025;
    // let road_shape = new THREE.Shape();
    // road_shape.moveTo(0, 0);
    // road_shape.lineTo(0, lane_width);
    // road_shape.lineTo(lane_height, lane_width);
    // road_shape.lineTo(lane_height, 0);
    // road_shape.lineTo(0, 0);

    // var road_shape_mesh =
    //     new THREE.Mesh(new THREE.ShapeGeometry(road_shape),
    //                    new THREE.MeshBasicMaterial({color : 0x00ff00}));
    // scene.add(road_shape_mesh);

    // // Create a sine-like wave
    // var road_curve = new THREE.SplineCurve(
    //     lanes[0].map((v) => new THREE.Vector2(v[0], v[1])));
    // console.log(road_curve);

    // let geometry = new THREE.ExtrudeBufferGeometry(road_shape, {
    //   steps : 4,
    //   depth : 16,
    //   bevelEnabled : false,
    //   // extrudePath : road_curve
    // });
    // console.log(geometry);
    // let material = new THREE.MeshBasicMaterial({color : 0x00ff00});
    // let road_mesh = new THREE.Mesh(geometry, material);
    // scene.add(road_mesh);

    // has_road = true;
  };

  let has_obstacles = false;
  const update_obstacles = (msg) => {
    const obstacles = msg.obstacles;
    if (!obstacles) {
      return;
    }
    // if (has_obstacles) {
    //   return;
    // }
    // has_obstacles = true;
    let obs_els = obstacles_svg.getElementsByClassName('obstacle');
    obstacles.forEach((obs, i) => {
      // SVG
      const points =
          obs.map((coord) => { return coord2svg(coord).slice(0, 2).join(); })
              .join(' ');
      let el = obs_els.item(i);
      if (!el) {
        el = document.createElementNS("http://www.w3.org/2000/svg", 'polygon');
        el.setAttributeNS(null, 'class', 'obstacle');
        obstacles_svg.appendChild(el);
      }
      el.setAttributeNS(null, 'points', points);
      // THREE.js
      // TODO: Check if this obstacle exists already
      let obs_shape = new THREE.Shape();
      obs_shape.moveTo(obs[0][0], obs[0][1]);
      obs.forEach((v, i) => {
        if (i > 0) {
          obs_shape.lineTo(v[0], v[1]);
        }
      });
      obs_shape.lineTo(obs[0][0], obs[0][1]);
      // Geometry from the underlying shape
      // TODO: Can we update just the shape, and the Extrude gets updated?
      let obs_geometry = new THREE.ExtrudeBufferGeometry(obs_shape, {
        steps : 1,
        depth : 0.5,
        bevelEnabled : false,
      });
      // Should only perform this once per obstacle
      const obs_mesh = new THREE.Mesh(
          obs_geometry,
          new THREE.MeshLambertMaterial(
              {color : 0xFF8080, transparent : true, opacity : 0.75}));
      scene.add(obs_mesh);
    });
  }; // end update_obstacles

  const update_vehicles = (msg) => {
    const vehicles = msg.vehicles;
    if (!vehicles) {
      return;
    }
    // SVG
    var vehicle_els = vehicles_svg.getElementsByClassName('vehicle');
    vehicles.map(coord2svg).forEach((v, i) => {
      var el = vehicle_els.item(i);
      if (!el) {
        el = document.createElementNS("http://www.w3.org/2000/svg", 'use');
        el.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href',
                          '#automobile');
        el.setAttributeNS(null, 'class', 'vehicle');
        // el = document.createElementNS("http://www.w3.org/2000/svg",
        // 'circle');
        // el.setAttributeNS(null, 'r', 0.125);
        // el.style.fill = "#F00";
        // el.style.stroke = "none";
        vehicles_svg.appendChild(el);
      }
      // el.setAttributeNS(null, 'cx', v[0] || 0);
      // el.setAttributeNS(null, 'cy', v[1] || 0);
      el.setAttributeNS(null, 'x', v[0]);
      el.setAttributeNS(null, 'y', v[1]);
      const tfm_vel =
          "rotate(" + [ v[2] * RAD_TO_DEG, v[0], v[1] ].join() + ")";
      el.setAttributeNS(null, 'transform', tfm_vel);
    });
    // THREE.js
    while (vehicles.length > veh_boxes.length) {
      const veh = veh_mesh.clone();
      scene.add(veh);
      veh_boxes.push(veh);
    }
    while (vehicles.length < veh_boxes.length) {
      scene.remove(veh_boxes.pop());
    }
    vehicles.forEach((v, i) => {
      let veh = veh_boxes[i];
      veh.position.x = v[0];
      veh.position.y = v[1];
      veh.rotation.z = v[2];
    });
  };

  const update_control = (msg) => {
    const ctrl = msg.control;
    if (!ctrl) {
      return;
    }
    const id_robot = ctrl.id;
    // Lookahead
    const p_lookahead = ctrl.p_lookahead;
    if (p_lookahead) {
      var pla_el = document.getElementById('lookahead_' + id_robot);
      if (!pla_el) {
        pla_el =
            document.createElementNS("http://www.w3.org/2000/svg", 'circle');
        pla_el.setAttributeNS(null, 'id', 'lookahead_' + id_robot);
        pla_el.setAttributeNS(null, 'r', 0.05);
        pla_el.setAttributeNS(null, 'class', 'lookahead');
        pla_el.style.fill = "red";
        pla_el.style.stroke = "none";
        observer_svg.appendChild(pla_el);
      }
      const pla = coord2svg(p_lookahead);
      pla_el.setAttributeNS(null, 'cx', pla[0]);
      pla_el.setAttributeNS(null, 'cy', pla[1]);
    }

    // Near
    const p_near = ctrl.p_path;
    if (p_near) {
      var pn_el = document.getElementById('near_' + id_robot);
      if (!pn_el) {
        pn_el =
            document.createElementNS("http://www.w3.org/2000/svg", 'circle');
        pn_el.setAttributeNS(null, 'id', 'near_' + id_robot);
        pn_el.setAttributeNS(null, 'r', 0.05);
        pn_el.setAttributeNS(null, 'class', 'near');
        pn_el.style.fill = "yellow";
        pn_el.style.stroke = "none";
        observer_svg.appendChild(pn_el);
      }
      const pn = coord2svg(p_near);
      const xn = pn[0] || 0, yn = pn[1] || 0;
      pn_el.setAttributeNS(null, 'cx', xn);
      pn_el.setAttributeNS(null, 'cy', yn);
    }

    // Pose
    const pose = ctrl.pose;
    if (pose) {
      var pose_el = document.getElementById('pose_' + id_robot);
      if (!pose_el) {
        pose_el = document.createElementNS("http://www.w3.org/2000/svg", 'use');
        pose_el.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href',
                               '#automobile');
        pose_el.setAttribute("fill", "brown");
        pose_el.setAttribute("stroke", "white");
        pose_el.setAttribute("fill-opacity", "0.75");
        // '#sweetvehicle');
        pose_el.setAttributeNS(null, 'id', 'pose_' + id_robot);
        observer_svg.appendChild(pose_el);
      }
      const p = coord2svg(pose);
      pose_el.setAttributeNS(null, 'x', p[0]);
      pose_el.setAttributeNS(null, 'y', p[1]);
      pose_el.setAttributeNS(
          null, 'transform',
          "rotate(" + [ p[2] * RAD_TO_DEG, p[0], p[1] ].join() + ")");
      // Add 3D mesh
      // console.log("id_robot", id_robot);
      let veh_box = id_robot == 'tri1' ? observer_mesh : veh_boxes[id_robot];
      if (!veh_box) {
        veh_box = veh_mesh.clone();
        scene.add(veh_box);
        veh_boxes[id_robot] = veh_box;
      }
      veh_box.position.x = pose[0];
      veh_box.position.y = pose[1];
      veh_box.rotation.z = pose[2];
    }
  };

  const update_3D = (msg) => {
    const beliefs = msg[likelihood_selection];
    if (!beliefs) {
      return;
    }

    // Ensure we have the same lanes
    while (beliefs.length > bel_boxes.length) {
      bel_boxes.push([]);
    }
    while (beliefs.length < bel_boxes.length) {
      bel_boxes.pop();
    }
    while (beliefs.length > risk_boxes.length) {
      risk_boxes.push([]);
    }
    while (beliefs.length < risk_boxes.length) {
      risk_boxes.pop();
    }

    // Iterate through the lanes
    beliefs.forEach((lb, il) => {
      // Only use the first lane for now
      let lbel_boxes = bel_boxes[il];
      while (lb.length > lbel_boxes.length) {
        let bm = bel_mesh.clone();
        bm.position.x = (lbel_boxes.length - lb.length / 2) * sz_box_path;
        scene.add(bm);
        lbel_boxes.push(bm);
      }
      while (lb.length < lbel_boxes.length) {
        let bm = lbel_boxes.pop();
        scene.remove(bm);
      }
      // This becomes the scale
      lb.map((b) => max(eps, 1 / (1 - Math.log(b)))).forEach((b, i, arr) => {
        let bm = lbel_boxes[i];
        bm.scale.y = b / sz_box_width;
        bm.position.y = (b / 2) + sz_box_width / 2;
      });
    });

    // Iterate through the lanes
    if ('conditioned_risk' in msg) {
      msg.conditioned_risk.forEach((lr, il) => {
        let lrisk_boxes = risk_boxes[il];
        while (lr.length > lrisk_boxes.length) {
          let rm = risk_mesh.clone();
          rm.position.x = (lrisk_boxes.length - lr.length / 2) * sz_box_path;
          scene.add(rm);
          lrisk_boxes.push(rm);
        }
        while (lr.length < lrisk_boxes.length) {
          scene.remove(lrisk_boxes.pop());
        }

        lr.map((b) => max(eps, 1 / (1 - Math.log(b)))).forEach((b, i) => {
          let rm = lrisk_boxes[i];
          rm.scale.z = b / sz_box_width;
          rm.position.z = (b / 2) + sz_box_width / 2;
        });
      });
    }

    // Apply a transform
    if ('waypoints' in msg) {
      msg.waypoints.forEach((lwp, il) => {
        lwp.forEach((wp, i, arr) => {
          let bm = bel_boxes[il][i];
          let rm = risk_boxes[il][i];
          if (rm === undefined || bm === undefined) {
            return;
          }
          bm.position.x = wp[0];
          bm.position.y = wp[1];

          if (i == 0) {
          } else if (i == arr.length - 1) {
          } else {
            const a = lwp[i - 1], b = lwp[i + 1];
            bm.rotation.z = rm.rotation.z =
                Math.atan2(b[1] - a[1], b[0] - a[0]);
          }
          // Risk
          rm.position.x = wp[0];
          rm.position.y = wp[1];
        });
      });
    }
  };

  const update_beliefs = (msg) => {
    const beliefs = msg[likelihood_selection];
    const waypoints = msg.waypoints;
    if (!beliefs || !waypoints) {
      return;
    }
    graph_ctx.clearRect(X_CANVAS_MIN, Y_CANVAS_MIN, X_CANVAS_SZ, Y_CANVAS_SZ);
    // Size of squares
    const s = svg2canvas_sz([ 0.075, 0.075 ]);
    var beliefs_els = lanes_svg.getElementsByClassName('belief');
    var counter = 0;
    beliefs.forEach((lb, il) => {
      const lwp = waypoints[il];
      lb = lb.map((b) => 1 / (1 - Math.log(b)));

      lb.forEach((b, i) => {
        // lb.forEach((b, i) => {
        const wp = coord2svg(lwp[i]);
        const p = svg2canvas([ wp[0], wp[1] ]);
        graph_ctx.fillStyle = to_jet(b, 0.75);
        // graph_ctx.fillStyle = to_rainbow(b, 0.75);
        graph_ctx.fillRect(p[0] - s[0] / 2, p[1] - s[0] / 2, s[0], s[1]);
        counter += 1;
      });
    });
  };

  const update_plot = (msg) => {
    const time = msg.t, risks = msg.risks;
    if (time === undefined || risks === undefined) {
      return;
    }

    // console.log("Gap", has_gap);
    // console.log("Plot Msg", msg);

    if (time < risk_times[risk_times.length - 1]) {
      risk_times = [];
      risk_over_time = [];
      gap_over_time = [];
      dj_over_time = [];
    }
    if (risk_times.length >= n_timesteps) {
      risk_times.shift();
      risk_over_time.forEach((r) => { r.shift(); });
      gap_over_time.shift();
      dj_over_time.shift();
    }
    const risk_acceptable = 0.075;

    // Add the time indicator
    risk_times.push(time);
    n_risk_times = risk_times.length;

    // Invert to mimic risk
    const has_gap = msg.gap ? 0 : 1;
    gap_over_time.push(has_gap);

    // As the car approaches the intersection: Shows nudging behavior
    const d_j = msg.d_j;
    dj_over_time.push(d_j);

    var data;
    const tclear_checks = msg.tclear_checks;
    const risk_checks = msg.risk_checks;

    // Default plot layout
    var layout = {
      title : 'Intersection Risk to Go',
      font : {
        family : 'Times',
        // family: 'Courier New, monospace',
        size : 18,
        // color: '#7f7f7f'
      },
      showlegend : true,
      legend : {borderwidth : 1},
      xaxis : {
        title : 'time (s)',
        titlefont : {size : 16},
        showgrid : false,
        zeroline : false
      },
      yaxis : {
        title : 'Conditioned Risk',
        titlefont : {size : 16},
        showgrid : false,
        zeroline : false,
        // range : [ 0, 2.5 ]
        range : [ 0, 2 ]
      },
      width : 840,
      height : 560,
      // width : 720,
      // height : 480,
      datarevision : time,
      // plot_bgcolor : "lightgray",
      plot_bgcolor : "#EEEEEE",
      // paper_bgcolor : "#FFF3"
    };

    const linings = [ 'solid', 'dash', 'dot', 'dashdot' ];

    if (d_j && false) {
      layout.xaxis.title = 'd<sub>e</sub>';
      layout.datarevision = d_j;
      msg.risk_checks.forEach((risks, i) => {
        var r = risks[risks.length - 1];
        // r = Math.log(r);
        // r = 1 / (1 - Math.log(r));
        if (i >= risk_over_time.length) {
          risk_over_time[i] = [ r ];
        } else {
          risk_over_time[i].push(r);
        }
      });
      data = risk_over_time.map((r, i, arr) => {
        const idx_lining = i % linings.length;
        const tc = tclear_checks[i];
        const my_tclear = r.map(() => tc);
        return {
          x : dj_over_time,
          y : r,
          type : 'scatter',
          mode : 'lines',
          name : 't<sub>c</sub> = ' + tc.toFixed(1) + 's',
          line : {
            dash : linings[idx_lining],
            width : 2 + 3 * (i - idx_lining) / linings.length,
            // color : to_jet0(i / (arr.length - 1)) || d3colors(i),
            color : d3colors(i),
          }
        };
      });
      data.push({
        showscale : false,
        x : [ dj_over_time[0], dj_over_time[n_risk_times - 1] ],
        y : [ risk_acceptable, risk_acceptable ],
        type : 'scatter',
        mode : 'lines+markers',
        name : 'r<sub>go</sub> = ' + risk_acceptable.toFixed(3),
        opacity : 0.5,
        line : {
          dash : 'solid',
          width : 3,
          color : 'green',
        },
        marker : {line : {color : 'black', width : 6}}
      });
      data.push({
        showscale : false,
        x : dj_over_time,
        y : gap_over_time,
        type : 'scatter',
        mode : 'lines+markers',
        name : 'Gap',
        opacity : 0.5,
        line : {
          dash : 'solid',
          width : 3,
          color : 'pink',
        }
      });
    } else if (tclear_checks && risk_checks) {
      // console.log(msg.tclear_checks, msg.risk_checks);
      // msg.risk_checks.map((r) => 1 / (1 - Math.log(r))).forEach((risks, i) =>
      // {
      msg.risk_checks.forEach((risks, i) => {
        var r = risks[risks.length - 1];
        // r = Math.log(r);
        // r = 1 / (1 - Math.log(r));
        if (i >= risk_over_time.length) {
          risk_over_time[i] = [ r ];
        } else {
          risk_over_time[i].push(r);
        }
      });

      data = risk_over_time.map((r, i, arr) => {
        const idx_lining = i % linings.length;
        const tc = tclear_checks[i];
        const my_tclear = r.map(() => tc);
        // console.log(risk_times, r, my_tclear);
        return {
          x : risk_times,
          y : r,
          type : 'scatter',
          mode : 'lines',
          name : 't<sub>c</sub> = ' + tc.toFixed(1) + 's',
          line : {
            dash : linings[idx_lining],
            width : 3 + 3 * (i - idx_lining) / linings.length,
            // color : to_jet0(i / (arr.length - 1)) || d3colors(i),
            color : d3colors(i),
          }
        };
      });
      data.push({
        showscale : false,
        x : [ risk_times[0], risk_times[n_risk_times - 1] ],
        y : [ risk_acceptable, risk_acceptable ],
        type : 'scatter',
        mode : 'lines+markers',
        name : 'r<sub>go</sub> = ' + risk_acceptable.toFixed(3),
        opacity : 0.5,
        line : {
          dash : 'solid',
          width : 3,
          color : 'violet',
        },
        marker : {line : {color : 'black', width : 6}}
      });
      data.push({
        showscale : false,
        x : risk_times,
        y : gap_over_time,
        type : 'scatter',
        mode : 'lines+markers',
        name : 'Gap',
        opacity : 0.5,
        line : {
          dash : 'solid',
          width : 3,
          color : 'pink',
        }
      });
    } else {
      // risk.map((b) => 1 / (1 - Math.log(b))).forEach((r, i) => {
      risks.forEach((r, i) => {
        if (i >= risk_over_time.length) {
          risk_over_time[i] = [ r ];
        } else {
          risk_over_time[i].push(r);
        }
      });

      data = risk_over_time.map((r, i, arr) => {
        return {
          x : risk_times,
          y : r,
          line : {color : to_jet(i / arr.length) || d3colors(i)},
          mode : 'lines',
          name : 'lane' + i,
          type : 'scatter',
        };
      });
      data[data.length - 1].name = 'total';
      data[data.length - 1].line.color = d3colors(9);
    }

    Plotly.react(graph_div, data, layout);
  };
  /*
  const update_plot = (msg) => {
    const time = msg.t, risks = msg.risks;
    if (time === undefined || risks === undefined) {
      return;
    }
    // console.log("Plot Msg", msg);

    if (time < risk_times[risk_times.length - 1]) {
      // risk_times = [];
      // risk_over_time = [];
      return;
    } else if (risk_times.length >= n_timesteps) {
      risk_times.shift();
      risk_over_time.forEach((r) => { r.shift(); });
    }

    // Add the time indicator
    risk_times.push(time);
    n_risk_times = risk_times.length;

    var data;
    if (msg.risk_checks) {
      // console.log(msg.tclear_checks, msg.risk_checks);
      // msg.risk_checks.map((r) => 1 / (1 - Math.log(r))).forEach((risks, i) =>
      // {
      msg.risk_checks.forEach((risks, i) => {
        var r = risks[risks.length - 1];
        // r = Math.log(r);
        // r = 1 / (1 - Math.log(r));
        if (i >= risk_over_time.length) {
          risk_over_time[i] = [ r ];
        } else {
          risk_over_time[i].push(r);
        }
      });

      const tclear_checks = msg.tclear_checks;
      const n_tclear = tclear_checks.length;
      data = risk_over_time.map((r, i, arr) => {
        const tc = tclear_checks[i];
        const my_tclear = r.map(() => tc);
        // console.log(risk_times, r, my_tclear);
        return {
          z : r,
          x : risk_times,
          y : my_tclear,
          type : 'scatter3d',
          mode : 'lines',
          name : 't_clear=' + tc.toFixed(2),
          line : {
            width : 12,
            color : to_jet0(i / (arr.length - 1)) || d3colors(i),
          }
        };
      });

      // data.push({z : [ [ 0.1, 0.1 ], [ 0.1, 0.1 ] ], type : 'surface'});
      data.push({
        showscale : false,
        z : [ [ 0.03, 0.03 ], [ 0.03, 0.03 ] ],
        x : [
          [ risk_times[0], risk_times[0] ],
          [ risk_times[n_risk_times - 1], risk_times[n_risk_times - 1] ]
        ],
        y : [
          [ tclear_checks[0], tclear_checks[n_tclear - 1] ],
          [ tclear_checks[0], tclear_checks[n_tclear - 1] ]
        ],
        type : 'surface',
        opacity : 0.75,
      });
    } else {
      // risk.map((b) => 1 / (1 - Math.log(b))).forEach((r, i) => {
      risks.forEach((r, i) => {
        if (i >= risk_over_time.length) {
          risk_over_time[i] = [ r ];
        } else {
          risk_over_time[i].push(r);
        }
      });

      data = risk_over_time.map((r, i, arr) => {
        return {
          x : risk_times,
          y : r,
          mode : 'lines',
          name : 'lane' + i,
          line : {color : to_jet(i / arr.length) || d3colors(i)}
        };
      });
      data[data.length - 1].name = 'total';
      data[data.length - 1].line.color = d3colors(9);
    }

    var layout = {
      title : 'Intersection Risk to Go',
      showlegend : false,
      // xaxis : {title : 'time', showgrid : false, zeroline : false},
      // yaxis : {
      //   title : 'Conditioned Risk',
      //   showline : false,
      //   // range : [ 0, 1 ]
      // },
      aspectmode : "manual",
      aspectratio : {
        x : 2,
        y : 0.5,
        z : 1,
      },
      camera : {eye : {x : -1.25, y : -1.25, z : 0.125}},
      scene : {
        xaxis : {title : 'time (s)', titlefont : {size : 32}},
        yaxis : {
          title : 't_clear (s)',
          titlefont : {size : 32},
          range : [ 2, 4.5 ]
        },
        zaxis : {
            range : [ 0, 2.5 ],
            // title : 'Risk', titlefont : {size : 32},
          },
      },
      width : 720,
      height : 720,
      datarevision : time
    };
    Plotly.react(graph_div, data, layout);
  };
  */

  ws.onmessage = (e) => {
    var msg = munpack(new Uint8Array(e.data));
    Object.assign(cur, msg);

    // console.log(msg);
    if (msg.risk !== undefined) {
      msg = msg.risk;
    }

    update_3D(msg);
    update_road(msg);
    update_obstacles(msg);
    update_vehicles(msg);
    // update_observer(msg);
    update_plot(msg);
    update_control(msg);
    update_beliefs(msg);

    const trajectory_turn = msg.trajectory_turn;
    if (trajectory_turn) {
      var trajectory_turn_els = lanes_svg.getElementsByClassName('trajectory');
      trajectory_turn.forEach((l, i) => {
        if (i > 0) {
          return;
        }
        const points =
            l.map((coord, i) => { return coord2svg(coord).slice(0, 2).join(); })
                .join(' ');
        var el = trajectory_turn_els.item(i);
        if (!el) {
          el = document.createElementNS("http://www.w3.org/2000/svg",
                                        'polyline');
          el.setAttributeNS(null, 'class', 'trajectory');
          el.style.fill = "none";
          el.style.stroke = "#0FA";
          // el.style.stroke = d3colors(i);
          el.style.strokeWidth = "0.1";
          lanes_svg.appendChild(el);
        }
        el.setAttributeNS(null, 'points', points);
      });
    }

    const time = msg.t;
    if (time !== undefined) {
      info_div.innerHTML =
          [ time.toFixed(2), msg.go ? "Go" : "No Go" ].join('<br/>');
    }
    const risks = msg.risks;

    if ('viewBox' in msg) {
      const changed = msg.viewBox.reduce(
          (eq, v, i) => { return eq || v !== viewBox[i]; }, false);
      if (changed) {
        // console.log("Changed viewBox", msg.viewBox, viewBox);
        viewBox = msg.viewBox;
        // Must flip the coordinates...
        X_SVG_MIN = parseFloat(viewBox[1]);
        Y_SVG_MIN = parseFloat(viewBox[0]);
        X_SVG_SZ = parseFloat(viewBox[3]);
        Y_SVG_SZ = parseFloat(viewBox[2]);
        environment_svg.setAttribute('viewBox', X_SVG_MIN + ' ' + Y_SVG_MIN +
                                                    ' ' + X_SVG_SZ + ' ' +
                                                    Y_SVG_SZ);
        update_canvas();
      }
    }
  };
  // Handle the radio change
  var rad = document.likelihoodSelection.likelihood;
  const radioHandler = (e) => {
    // console.log(e);
    // console.log(this);
    // console.log(e.srcElement);
    // console.log(likelihood_selection, e.srcElement.id);
    likelihood_selection = e.srcElement.id;
  };
  var prev = null;
  for (var i = 0; i < rad.length; i++) {
    // rad[i].onchange = radioHandler;
    rad[i].addEventListener('change', radioHandler);
  }

  var img_video1 = document.getElementById('video1');
  var img_video2 = document.getElementById('video2');
  var img_video3 = document.getElementById('video3');
  const draw = (timestamp) => {
    window.requestAnimationFrame(draw);
    const t = Date.now();
    const video1 = cur.video1 || cur.video0;
    if (video1) {
      cur.video1 = false;
      const blobJ = new Blob([ video1.jpg ], {'type' : 'image/jpeg'});
      window.URL.revokeObjectURL(img_video1.src);
      img_video1.src = window.URL.createObjectURL(blobJ);
      // img_camera.onload = (e) => { console.log("done") };
    }
    const video2 = cur.video2;
    if (video2) {
      cur.video2 = false;
      const blobJ = new Blob([ video2.jpg ], {'type' : 'image/jpeg'});
      window.URL.revokeObjectURL(img_video2.src);
      img_video2.src = window.URL.createObjectURL(blobJ);
      // img_camera.onload = (e) => { console.log("done") };
    }
    const video3 = cur.video3;
    if (video3) {
      cur.video3 = false;
      const blobJ = new Blob([ video3.jpg ], {'type' : 'image/jpeg'});
      window.URL.revokeObjectURL(img_video3.src);
      img_video3.src = window.URL.createObjectURL(blobJ);
      // img_camera.onload = (e) => { console.log("done") };
    }
  };

  draw();
});
