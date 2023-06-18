package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxMath;
import flixel.transition.FlxTransitionableState;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxTimer;
import lime.utils.Assets as LimeAssets;
import openfl.utils.Assets;

class LoadingState extends MusicBeatState
{
	inline static var MIN_TIME = 1.0;

	// Browsers will load create(), you can make your song load a custom directory there
	// If you're compiling to desktop (or something that doesn't use NO_PRELOAD_ALL), search for getNextState instead
	// I'd recommend doing it on both actually lol
	// TO DO: Make this easier
	var target:FlxState;
	var stopMusic = false;
	var directory:String;
	var callbacks:MultiCallback;
	var targetShit:Float = 0;

	function new(target:FlxState, stopMusic:Bool, directory:String)
	{
		super();
		this.target = target;
		this.stopMusic = stopMusic;
		this.directory = directory;
	}

	var funkay:FlxSprite;
	var funkayOGWidth:Float = FlxG.width;
	var loadBar:FlxSprite;

	override function create()
	{
		super.create();

		var imagePath = Paths.image('funkay');

		var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xffcaff4d);
		add(bg);
		funkay = new FlxSprite(0, 0).loadGraphic(imagePath);
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		funkay.antialiasing = ClientPrefs.globalAntialiasing;
		add(funkay);
		funkay.scrollFactor.set();
		funkay.screenCenter();
		funkayOGWidth = funkay.width;
		bg.makeGraphic(FlxG.width, FlxG.height, CoolUtil.dominantColor(funkay));

		loadBar = new FlxSprite(0, FlxG.height - 20).makeGraphic(FlxG.width, 10, 0xffff16d2);
		loadBar.screenCenter(X);
		loadBar.antialiasing = ClientPrefs.globalAntialiasing;
		add(loadBar);

		Paths.loadLibraryManifest('songs').onComplete(function(lib)
		{
			callbacks = new MultiCallback(onLoad);
			var introComplete = callbacks.add("introComplete");
			/*if (PlayState.SONG != null) {
				checkLoadSong(getSongPath());
				if (CoolUtil.existsVoices(PlayState.SONG.song)) {
					checkLoadSong(getVocalPath());
					checkLoadSong(getDadVocalPath());
				}
			}*/
			checkLibrary("shared");
			if (directory != null && directory.length > 0 && directory != 'shared')
			{
				checkLibrary(directory);
			}

			var fadeTime = 0.5;
			FlxG.camera.fade(FlxG.camera.bgColor, fadeTime, true);
			new FlxTimer().start(fadeTime + MIN_TIME, function(_) introComplete());
		});

		FlxTransitionableState.skipNextTransOut = true;
	}

	function checkLoadSong(path:String)
	{
		if (Assets.exists(path) && !Assets.cache.hasSound(path))
		{
			var callback = callbacks.add('song:$path');
			Assets.loadSound(path).onComplete(function(_)
			{
				callback();
			});
		}
	}

	function checkLibrary(library:String)
	{
		trace(Assets.hasLibrary(library));
		if (Assets.getLibrary(library) == null)
		{
			@:privateAccess
			if (!LimeAssets.libraryPaths.exists(library))
				throw 'Missing library: $library';

			var callback = callbacks.add('library:$library');
			Assets.loadLibrary(library).onComplete(function(_)
			{
				callback();
			});
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		funkay.setGraphicSize(Std.int(FlxMath.lerp(funkay.width, funkayOGWidth, CoolUtil.boundTo(elapsed * 12, 0, 1))));
		funkay.updateHitbox();
		if (controls.ACCEPT)
		{
			funkay.setGraphicSize(Std.int(funkay.width + 60));
			funkay.updateHitbox();
		}

		if (callbacks != null)
		{
			targetShit = FlxMath.remapToRange(callbacks.numRemaining / callbacks.length, 1, 0, 0, 1);
			loadBar.scale.x += 0.5 * (targetShit - loadBar.scale.x);
		}
	}

	function onLoad()
	{
		if (stopMusic)
		{
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();
			FreeplayState.instPlaying = -1;
		}

		MusicBeatState.switchState(target);
	}

	static function getSongPath()
	{
		var diffPath = 'songs:assets/songs/${Paths.formatToSongPath(PlayState.SONG.song)}/Inst${CoolUtil.getDifficultyFilePath()}.${Paths.SOUND_EXT}';
		if (Paths.exists(diffPath))
			return diffPath;
		return 'songs:assets/songs/${Paths.formatToSongPath(PlayState.SONG.song)}/Inst.${Paths.SOUND_EXT}';
	}

	static function getVocalPath()
	{
		var diffPath = 'songs:assets/songs/${Paths.formatToSongPath(PlayState.SONG.song)}/Voices${CoolUtil.getDifficultyFilePath()}.${Paths.SOUND_EXT}';
		if (Paths.exists(diffPath))
			return diffPath;
		return 'songs:assets/songs/${Paths.formatToSongPath(PlayState.SONG.song)}/Voices.${Paths.SOUND_EXT}';
	}

	static function getDadVocalPath()
	{
		var path = 'songs:assets/songs/${Paths.formatToSongPath(PlayState.SONG.song)}/VoicesDad.${Paths.SOUND_EXT}';
		var path2 = 'songs:assets/songs/${Paths.formatToSongPath(PlayState.SONG.song)}/VoicesOpponent.${Paths.SOUND_EXT}';
		if (Assets.exists(path2))
		{
			path = path2;
		}
		return path;
	}

	inline static public function loadAndSwitchState(target:FlxState, stopMusic = false)
	{
		MusicBeatState.switchState(getNextState(target, stopMusic));
	}

	inline static public function loadAndResetState(stopMusic = false)
	{
		loadAndSwitchState(Type.createInstance(Type.getClass(FlxG.state), []), stopMusic);
	}

	static function getNextState(target:FlxState, stopMusic = false):FlxState
	{
		var directory:String = 'shared';
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if (weekDir != null && weekDir.length > 0 && weekDir != '')
			directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to $directory');

		#if NO_PRELOAD_ALL
		var loaded:Bool = false;
		if (PlayState.SONG != null)
		{
			loaded = /*isSoundLoaded(getSongPath()) && (!CoolUtil.existsVoices(PlayState.SONG.song) || (isSoundLoaded(getVocalPath()) && isSoundLoaded(getDadVocalPath()))) && */ isLibraryLoaded("shared")
				&& isLibraryLoaded(directory);
		}

		if (!loaded)
			return new LoadingState(target, stopMusic, directory);
		#end
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		return target;
	}

	#if NO_PRELOAD_ALL
	static function isSoundLoaded(path:String):Bool
	{
		return Assets.cache.hasSound(path) || !Assets.exists(path);
	}

	static function isLibraryLoaded(library:String):Bool
	{
		return Assets.getLibrary(library) != null;
	}
	#end

	override function destroy()
	{
		target = null;
		directory = null;
		callbacks = null;
		funkay = FlxDestroyUtil.destroy(funkay);
		loadBar = FlxDestroyUtil.destroy(loadBar);
		super.destroy();
	}
}

class MultiCallback
{
	public var callback:Void->Void;
	public var logId:String = null;
	public var length(default, null) = 0;
	public var numRemaining(default, null) = 0;

	var unfired = new Map<String, Void->Void>();
	var fired = new Array<String>();

	public function new(callback:Void->Void, logId:String = null)
	{
		this.callback = callback;
		this.logId = logId;
	}

	public function add(id = "untitled")
	{
		id = '$length:$id';
		length++;
		numRemaining++;
		var func:Void->Void = null;
		func = function()
		{
			if (unfired.exists(id))
			{
				unfired.remove(id);
				fired.push(id);
				numRemaining--;

				if (logId != null)
					log('fired $id, $numRemaining remaining');

				if (numRemaining == 0)
				{
					if (logId != null)
						log('all callbacks fired');
					callback();
				}
			}
			else
				log('already fired $id');
		}
		unfired[id] = func;
		return func;
	}

	inline function log(msg):Void
	{
		if (logId != null)
			trace('$logId: $msg');
	}

	public function getFired()
		return fired.copy();

	public function getUnfired()
		return [for (id in unfired.keys()) id];
}
