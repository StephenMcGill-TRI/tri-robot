if ( ! Detector.webgl ) Detector.addGetWebGLMessage();

var ctxwidth = 400;
var ctxheight = 400;
var kwidth = 320;
var kheight = 240;
var particles = kwidth*kheight;

// Globals
var particleSystem, plane;
var container, stats;
var camera, controls, scene, renderer;
var positions, colors, vertices, geometry, faces;

init();
animate();

function init() {

  // Set up the camera
  camera = new THREE.PerspectiveCamera();
  camera.position.x = kwidth/2;
  camera.position.y = kheight/2;
  camera.position.z = 500;

  // Set up the mouse controls
  controls = new THREE.TrackballControls( camera );
  controls.rotateSpeed = 1.0;
  controls.zoomSpeed = 1.2;
  controls.panSpeed = 0.8;
  controls.noZoom = false;
  controls.noPan = false;
  controls.staticMoving = true;
  controls.dynamicDampingFactor = 0.3;
  controls.keys = [ 65, 83, 68 ];
  controls.addEventListener( 'change', render );

/*
  // Initialize the particles
  geometry = new THREE.BufferGeometry();
  geometry.attributes = {
    position: {
      itemSize: 3,
      array: new Float32Array( particles * 3 ),
      numItems: particles * 3
    }
  }
  geometry.dynamic = true;
  // Set the colors and positions
  positions = geometry.attributes.position.array;
  var cnt = 0;
  for( var j=0; j<240; j++ ){
    for( var i=0; i<320; i++ ){
      positions[cnt] = i;
      positions[cnt+1] = j;
      positions[cnt+2] = 0;
      cnt = cnt+3;
    }
 }
geometry.verticesNeedUpdate = true;
geometry.computeBoundingSphere();
geometry.computeTangents();
geometry.computeVertexNormals()
*/

  // Add the Image plane
  var image = new Uint8Array(320*190*4)
  for (var i = 0;i<kwidth*kheight; i=i+4) {
    image[i] = 255; // R
    image[i+1] = 0; // G
    image[i+2] = 0; // B
    image[i+3] = 255; // A
  }
  var plane_texture = new THREE.DataTexture( image, kwidth, kheight);
  plane_mat = new THREE.MeshBasicMaterial( {
    color: 0xffffff,
    wireframe: true,
    transparent: false,
    opacity : 1,
    map: plane_texture
  } );
  plane = new THREE.Mesh(
    new THREE.PlaneGeometry( kwidth, kheight, kwidth, kheight ),
    //geometry,
    plane_mat
  );

//plane.geometry.applyMatrix( new THREE.Matrix4().makeRotationX( - Math.PI / 2 ) );
vertices = plane.geometry.vertices;
faces = plane.geometry.faces;
/*
var cnt = 0;
  for( var j=0; j<240; j++ ){
    for( var i=0; i<320; i++ ){
//    vertices[cnt].x = i;
//    vertices[cnt].y = j;
    vertices[ faces[cnt].a ].z = 10*(i/320);
    vertices[ faces[cnt].b ].z = 10*(i/320);
    vertices[ faces[cnt].c ].z = 10*(i/320);
    vertices[ faces[cnt].d ].z = 10*(i/320);
faces
cnt = cnt+1;
    }
  }
*/
plane.geometry.computeVertexNormals()
plane.geometry.computeFaceNormals()

console.log(plane.geometry)

plane.geometry.dynamic = true;
  plane_texture.needsUpdate = true;
  plane_mat.needsUpdate = true;
  plane.geometry.verticesNeedUpdate = true;
//  plane.geometry.elementsNeedUpdate = true;
//  plane.geometry.uvsNeedUpdate = true;
  plane.geometry.normalsNeedUpdate = true;

  // Set up the world
  scene = new THREE.Scene();
  scene.add( plane );

  // Renderer
  renderer = new THREE.WebGLRenderer( { antialias: false, clearColor: 0x333333, clearAlpha: 1, alpha: false } );
  renderer.setSize( ctxwidth, ctxheight );
  container = document.getElementById( 'container' );
  container.appendChild( renderer.domElement );

  // FPS Stats
/*
  stats = new Stats();
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.top = '0px';
  stats.domElement.style.zIndex = 100;
  container.appendChild( stats.domElement );
*/

}

function animate() {
  requestAnimationFrame( animate );
  controls.update();
}

function render() {
  renderer.render( scene, camera );
//  stats.update();
}

function update_kinect_image( data_buffer ) {
  // Redo the RGB data for the texture
  plane_mat.map.image.data = data_buffer;
  //var new_texture = new THREE.DataTexture( data_buffer, kwidth, kheight);
  //plane_mat.map = new_texture;
  plane_mat.map.needsUpdate = true;

  animate();
  render();
}

function update_kinect_particles( d ) {

/*
  for ( var i = 0; i < positions.length; i += 3 )
    positions[ i + 2 ] = d[i];
  geometry.verticesNeedUpdate = true;
*/
/*
  for (var i = 0; i<vertices.length; i++ ){
    vertices[i].z = d[i]
  }
*/
for(var j=0; j<240; j++ ){
  for (var i = 0; i<320; i++ ){
fdx = j*320+i;
ddx = j*320+i;

    vertices[faces[fdx].a].z = 255-d[ddx];
    vertices[faces[fdx].b].z = 255-d[ddx];
    vertices[faces[fdx].c].z = 255-d[ddx];
    vertices[faces[fdx].d].z = 255-d[ddx];
  }
}
  plane.geometry.verticesNeedUpdate = true;
//plane.geometry.elementsNeedUpdate = true;
//plane.geometry.uvsNeedUpdate = true;
//plane.geometry.normalsNeedUpdate = true;
plane.geometry.computeVertexNormals()
plane.geometry.computeFaceNormals()

  animate();
  render();
}
