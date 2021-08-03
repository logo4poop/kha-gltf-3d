/*
 * Mostly stolen from http://kodegarden.org/#23e3537d948fca9b9bc3e5e933400e3a2ec672ae
 * I believe I only replaced the obj lines with glb loading.
 */
package;

import gltf.GLTF;
import kha.Framebuffer;
import kha.Assets;
import kha.Color;
import kha.Image;
import kha.Shaders;
import kha.Scheduler;
import kha.input.Keyboard;
import kha.input.Mouse;
import kha.input.KeyCode;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexBuffer;
import kha.graphics4.VertexShader;
import kha.graphics4.VertexData;
import kha.graphics4.IndexBuffer;
import kha.graphics4.PipelineState;
import kha.graphics4.ConstantLocation;
import kha.graphics4.TextureUnit;
import kha.graphics4.CompareMode;
import kha.graphics4.CullMode;
import kha.graphics4.Usage;
import kha.math.FastVector3;
import kha.math.FastMatrix4;

class Project {
	var vertexBuffer:VertexBuffer;
	var indexBuffer:IndexBuffer;
	var pipeline:PipelineState;

	var mvp:FastMatrix4;
	var mvpID:ConstantLocation;
	var viewMatrixID:ConstantLocation;
	var modelMatrixID:ConstantLocation;
	var lightID:ConstantLocation;

	var model:FastMatrix4;
	var view:FastMatrix4;
	var projection:FastMatrix4;

	var textureID:TextureUnit;
	var image:Image;

	var lastTime = 0.0;

	var position:FastVector3 = new FastVector3(0, 0, 5); // Initial position: on +Z
	var horizontalAngle = 3.14; // Initial horizontal angle: toward -Z
	var verticalAngle = 0.0; // Initial vertical angle: none

	var moveForward = false;
	var moveBackward = false;
	var strafeLeft = false;
	var strafeRight = false;
	var isMouseDown = false;

	var mouseX = 0.0;
	var mouseY = 0.0;
	var mouseDeltaX = 0.0;
	var mouseDeltaY = 0.0;

	var speed = 3.0; // 3 units / second
	var mouseSpeed = 0.005;	
	
	public function new() {}

	public function loadingFinished() {
		// Define vertex structure
		var structure = new VertexStructure();
		structure.add("pos", VertexData.Float3);
		structure.add("uv", VertexData.Float2);
		structure.add("nor", VertexData.Float3);
		// Save length - we store position, uv and normal data
		var structureLength = 8;

		// Compile pipeline state
		pipeline = new PipelineState();
		pipeline.inputLayout = [structure];
		pipeline.vertexShader = Shaders.simple_vert;
		pipeline.fragmentShader = Shaders.simple_frag;
		// Set depth mode
		pipeline.depthWrite = true;
		pipeline.depthMode = CompareMode.Less;
		// Set culling
		pipeline.cullMode = CullMode.Clockwise;
		pipeline.compile();

		// Get handles for our uniforms
		mvpID = pipeline.getConstantLocation("MVP");
		viewMatrixID = pipeline.getConstantLocation("V");
		modelMatrixID = pipeline.getConstantLocation("M");
		lightID = pipeline.getConstantLocation("lightPos");

		// Get a handle for texture sample
		textureID = pipeline.getTextureUnit("myTextureSampler");

		// Texture
		image = Assets.images.uvmap;

		// Projection Matrix
		projection = FastMatrix4.perspectiveProjection(45.0, 4.0 / 3.0, 0.1, 100.0);

		// Camera matrix
		view = FastMatrix4.lookAt(new FastVector3(4, 3, 3), // Camera is at (4, 3, 3), in World Space
				new FastVector3(0, 0, 0), // and looks at the origin
				new FastVector3(0, 1, 0) // Head is up (set to (0, -1, 0) to look upside-down)
		);

		// Model matrix: an identity matrix (model will be at the origin)
		model = FastMatrix4.identity();
		
		// ModelViewProjection
		mvp = FastMatrix4.identity();
		mvp = mvp.multmat(projection);
		mvp = mvp.multmat(view);
		mvp = mvp.multmat(model);
		
		// Loading 
		var obj = GLTF.parseAndLoadGLB(Assets.blobs.suzanne_glb.toBytes());
		var indices = obj.meshes[0].primitives[0].getIndexValues();
		var vertices = obj.meshes[0].primitives[0].attributes[0].accessor.getFloats();
		
		// Create vertex buffer
		vertexBuffer = new VertexBuffer(
				Std.int(vertices.length / structureLength), // Vertex count
				structure, // Vertex structure
				Usage.StaticUsage // Vertex data will stay the same
		);

		// Copy vertices to vertex buffer
		var vbData = vertexBuffer.lock();
		for (i in 0...vbData.length) {
			vbData.set(i, vertices[i]);
		}
		vertexBuffer.unlock();
		
		// Create index buffer
		indexBuffer = new IndexBuffer(
			indices.length, // Number of indices for our cube
			Usage.StaticUsage // Index data will stay the same
		);

		// Copy indices to index buffer
		var iData = indexBuffer.lock();
		for (i in 0...iData.length) {
			iData[i] = indices[i];
		}
		indexBuffer.unlock();

		// Add mouse and keyboard listeners
		kha.input.Mouse.get().notify(onMouseDown, onMouseUp, onMouseMove, null);
		kha.input.Keyboard.get().notify(onKeyDown, onKeyUp);

		// Used to calculate delta time
		lastTime = Scheduler.time();
	}

	public function update(): Void {
		// Compute time difference between current and last frame
		var deltaTime = Scheduler.time() - lastTime;
		lastTime = Scheduler.time();

		// Compute new orientation
		if (isMouseDown) {
			horizontalAngle += mouseSpeed * mouseDeltaX * -1;
			verticalAngle += mouseSpeed * mouseDeltaY * -1;
		}

		// Direction : Spherical coordinates to Cartesian coordinates conversion
		var direction = new FastVector3(
				Math.cos(verticalAngle) * Math.sin(horizontalAngle),
				Math.sin(verticalAngle),
				Math.cos(verticalAngle) * Math.cos(horizontalAngle)
				);

		// Right vector
		var right = new FastVector3(
				Math.sin(horizontalAngle - 3.14 / 2.0), 
				0,
				Math.cos(horizontalAngle - 3.14 / 2.0)
				);

		// Up vector
		var up = right.cross(direction);

		// Movement
		if (moveForward) {
			var v = direction.mult(deltaTime * speed);
			position = position.add(v);
		}
		if (moveBackward) {
			var v = direction.mult(deltaTime * speed * -1);
			position = position.add(v);
		}
		if (strafeRight) {
			var v = right.mult(deltaTime * speed);
			position = position.add(v);
		}
		if (strafeLeft) {
			var v = right.mult(deltaTime * speed * -1);
			position = position.add(v);
		}

		// Look vector
		var look = position.add(direction);

		// Camera matrix
		view = FastMatrix4.lookAt(position, // Camera is here
				look, // and looks here : at the same position, plus "direction"
				up // Head is up (set to (0, -1, 0) to look upside-down)
				);

		// Update model-view-projection matrix
		mvp = FastMatrix4.identity();
		mvp = mvp.multmat(projection);
		mvp = mvp.multmat(view);
		mvp = mvp.multmat(model);

		mouseDeltaX = 0;
		mouseDeltaY = 0;
	}

	public function render(frames: Array<Framebuffer>): Void {
		// A graphics object which lets us perform 3D operations
		var g = frames[0].g4;

		g.begin();

		g.clear(Color.fromFloats(0.0, 0.0, 0.3), 1.0);

		// Bind data we want to draw
		g.setVertexBuffer(vertexBuffer);
		g.setIndexBuffer(indexBuffer);

		// Bind state we want to draw with
		g.setPipeline(pipeline);

		// Set our uniforms
		g.setMatrix(mvpID, mvp);
		g.setMatrix(modelMatrixID, model);
		g.setMatrix(viewMatrixID, view);

		// Set light position to (4, 4, 4)
		g.setFloat3(lightID, 4, 4, 4);

		// Set texture
		g.setTexture(textureID, image);

		g.drawIndexedVertices();

		g.end();
	}

	function onMouseDown(button:Int, x:Int, y:Int) {
		isMouseDown = true;
	}

	function onMouseUp(button:Int, x:Int, y:Int) {
		isMouseDown = false;
	}

	function onMouseMove(x:Int, y:Int, movementX:Int, movementY:Int) {
		mouseDeltaX = x - mouseX;
		mouseDeltaY = y - mouseY;

		mouseX = x;
		mouseY = y;
	}

	function onKeyDown(key:Int) {
		if (key == KeyCode.Up) moveForward = true;
		else if (key == KeyCode.Down) moveBackward = true;
		else if (key == KeyCode.Left) strafeLeft = true;
		else if (key == KeyCode.Right) strafeRight = true;
	}

	function onKeyUp(key:Int) {
		if (key == KeyCode.Up) moveForward = false;
		else if (key == KeyCode.Down) moveBackward = false;
		else if (key == KeyCode.Left) strafeLeft = false;
		else if (key == KeyCode.Right) strafeRight = false;
	}
}
