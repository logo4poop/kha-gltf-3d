package;

import kha.Assets;
import kha.Scheduler;
import kha.System;

class Main {
	public static function main() {
		System.start({title: "Kha GLTF", width: 1280, height: 720}, function (_) {
			var game = new Project();
			Assets.loadEverything(function () {
				game.loadingFinished();
				Scheduler.addTimeTask(function () { game.update(); }, 0, 1 / 60);
				System.notifyOnFrames(function (frames) { game.render(frames); });
			});
		});
	}
}
