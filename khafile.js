let project = new Project('New Project');

project.addLibrary('haxe-gltf');
project.addAssets('Assets/**');
project.addShaders('Shaders/**');
project.addSources('Sources');

resolve(project);
