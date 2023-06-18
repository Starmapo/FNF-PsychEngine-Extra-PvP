package editors;

import animateatlas.AtlasFrameMaker;
import flash.display.PNGEncoderOptions;
import flash.utils.ByteArray;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.animation.FlxAnimation;
import flixel..FlxGridOverlay;
import flixel.s.frames.FlxFrame;
import flixel.s.frames.FlxFramesCollection;
import flixel.eyboard.FlxKey;
import flixel.xPoint;
import flixel.xText;
import flixel.ui.FlxButton;
import flixel.ui.FlxUI;
import flixel.ui.FlxUICheckBox;
import flixel.ui.FlxUIInputText;
import flixel.ui.FlxUINumericStepper;
import flixel.ui.FlxUIState;
import flixel.ui.FlxUITabMenu;
import flixel.util.FlxColor;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;

using StringTools;

enum AtlasType {
	SPARROW; //Sparrow atlases, basically almost every single one (.png & .xmls)
    PACKER; //Sprite Sheet Packer atlases, like Spirit (.png & .txt)
    TEXTURE; //Adobe Animate texture atlases, like FNF HD (spritemap.png, spritemap.json, & Animation.json)
    PACKERJSON; //TexturePacker atlases, like NekoFreak (.png & .json)
}

typedef SpritesheetData = {
    var animations:Array<AnimData>;
    var flipX:Bool;
    var flipY:Bool;
    var noAntialiasing:Bool;
    var scale:Float;
}

typedef AnimData = {
    var name:String;
}

/*
    NOTE:
    NOT ALL OF THIS CODE WAS THOUGHT OF BY ME
    I'M NOT THAT SMART
    HERE ARE THE THANKS THAT I HAVE REMEMBERED TO GIVE OUT
    https://github.com/ShadowMario/FNF-PsychEngine
    https://gist.github.com/miltoncandelero/0c452f832fa924bfdd60fe9d507bc581
    https://stackoverflow.com/questions/16273440/haxe-nme-resizing-a-bitmap
*/

class AnimationExportState extends FlxUIState {
    public static var muteKeys:Array<FlxKey> = [ZERO, NUMPADZERO];
    public static var volumeDownKeys:Array<FlxKey> = [MINUS, NUMPADMINUS];
    public static var volumeUpKeys:Array<FlxKey> = [PLUS, NUMPADPLUS];

    var daSprite:FlxSprite;
    var curSelected:Int = 0;
    var curAnimation:Int = 0;

    var gridBG:FlxSprite;
    public static var inputArray:Array<String> = [];
    public static var inputTypes:Map<String, AtlasType> = new Map<String, AtlasType>();
    var camEditor:FlxCamera;
	var camMenu:FlxCamera;
    var camHUD:FlxCamera;
    var camFollow:FlxPoint;
    var camFollowPos:FlxObject;
    var textAnim:FlxText;

    var UI_box:FlxUITabMenu;

    public static var textures:Map<String, FlxFramesCollection> = new Map<String, FlxFramesCollection>();
    public static var dataMap:Map<String, SpritesheetData> = new Map<String, SpritesheetData>();
    var currentData:SpritesheetData;

	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];

    override function create()
    {
        getInputs(true);

        camEditor = new FlxCamera();
        camEditor.bgColor = FlxColor.BLACK;
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;
        camMenu = new FlxCamera();
        camMenu.bgColor.alpha = 0;

        FlxG.cameras.reset(camEditor);
        FlxG.cameras.setDefaultDrawTarget(camEditor, true);
        FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camMenu, false);

        camFollow = new FlxPoint(FlxG.width / 2, FlxG.height / 2);
		camFollowPos = new FlxObject(0, 0, 1, 1);
        add(camFollowPos);
        FlxG.camera.follow(camFollowPos, LOCKON, 1);
        FlxG.camera.focusOn(camFollow);
        FlxG.fixedTimestep = false;

        gridBG = FlxGridOverlay.create(40, 40, -1, -1, true, 0xff333333, 0xff262626);
        gridBG.scrollFactor.set();
        add(gridBG);

        var tipText:FlxText = new FlxText(FlxG.width - 20, FlxG.height, 0,
			"E/Q - Camera Zoom In/Out
            \nR - Reset Camera Zoom
			\nWASD - Move Camera
			\nUp/Down - Previous/Next Animation
			\nSpace - Pause/Play Animation
            \n,/. - Previous/Next Frame
			\nLeft/Right - Change Spritesheet
			\nHold Shift to Move 2x faster\n", 12);
		tipText.cameras = [camHUD];
		tipText.setFormat(null, 12, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.x -= tipText.width;
		tipText.y -= tipText.height - 10;
		add(tipText);

        textAnim = new FlxText(300, 16, 0, '', 32);
		textAnim.setFormat(null, 32, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		textAnim.borderSize = 1;
		textAnim.scrollFactor.set();
		textAnim.cameras = [camHUD];
		add(textAnim);

        var tabs = [
			{name: 'Animation', label: 'Animation'},
            {name: 'Files', label: 'Files'}
		];
        UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.cameras = [camMenu];
		UI_box.resize(350, 250);
		UI_box.x = FlxG.width - 400;
		UI_box.y = 25;
		UI_box.scrollFactor.set();
		add(UI_box);

        addAnimationUI();
        addFilesUI();

        changeSelection();

        super.create();
    }

    var flipXCheckBox:FlxUICheckBox;
    var flipYCheckBox:FlxUICheckBox;
	var noAntialiasingCheckBox:FlxUICheckBox;
    var scaleStepper:FlxUINumericStepper;
    function addAnimationUI() {
        var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Animation";

        flipXCheckBox = new FlxUICheckBox(10, 25, null, null, "Flip X", 50);
		flipXCheckBox.callback = function() {
			daSprite.flipX = flipXCheckBox.checked;
            saveCurrentData();
		};

        flipYCheckBox = new FlxUICheckBox(flipXCheckBox.x + 70, 25, null, null, "Flip Y", 50);
		flipYCheckBox.callback = function() {
			daSprite.flipY = flipYCheckBox.checked;
            saveCurrentData();
		};

        noAntialiasingCheckBox = new FlxUICheckBox(flipYCheckBox.x + 70, 25, null, null, "No Antialiasing", 80);
		noAntialiasingCheckBox.callback = function() {
			daSprite.antialiasing = !noAntialiasingCheckBox.checked;
            saveCurrentData();
		};

        scaleStepper = new FlxUINumericStepper(noAntialiasingCheckBox.x + 130, 25, 0.1, 1, 0.05, 100, 2);
        blockPressWhileTypingOnStepper.push(scaleStepper);

        tab_group.add(new FlxText(scaleStepper.x, scaleStepper.y - 15, 0, 'Scale:'));
        tab_group.add(flipXCheckBox);
        tab_group.add(flipYCheckBox);
		tab_group.add(noAntialiasingCheckBox);
        tab_group.add(scaleStepper);
        UI_box.addGroup(tab_group);
    }

    function addFilesUI() {
        var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Files";

        var saveFrame:FlxButton = new FlxButton(10, 25, "Save Current Frame", function()
		{
            if (daSprite.animation.curAnim != null) {
                var file = '${inputArray[curSelected]}/${daSprite.frame.name}';
                if (FileSystem.exists('OUTPUT/$file.png')) {
                    FileSystem.deleteFile('OUTPUT/$file.png');
                }
                saveBitmapFromFrame(daSprite.frame, file, getAnimRect(daSprite.animation.curAnim));
                if (FileSystem.exists('OUTPUT/$file.png')) {
                    FlxG.sound.play('assets/sounds/confirmMenu.ogg');
                }
            }
		});
        saveFrame.setGraphicSize(Std.int(saveFrame.width), Std.int(saveFrame.height * 2));
		changeAllLabelsOffset(saveFrame, 0, -6);

        var saveAnim:FlxButton = new FlxButton(saveFrame.x + 100, 25, "Save Current Animation", function()
        {
            if (daSprite.animation.curAnim != null) {
                var daAnim = daSprite.animation.curAnim;
                var checkName = '';
                for (frame in daAnim.frames) {
                    var daFrame = daSprite.frames.frames[frame];
                    saveBitmapFromFrame(daFrame, '${inputArray[curSelected]}/${daFrame.name}', getAnimRect(daAnim));
                    if (checkName.length < 1) {
                        checkName = daFrame.name;
                    }
                }
                if (FileSystem.exists('OUTPUT/${inputArray[curSelected]}/$checkName.png')) {
                    FlxG.sound.play('assets/sounds/confirmMenu.ogg');
                }
            }
        });
        saveAnim.setGraphicSize(Std.int(saveAnim.width), Std.int(saveAnim.height * 2));
        changeAllLabelsOffset(saveAnim, 0, -6);

        var saveAllFrames:FlxButton = new FlxButton(saveAnim.x + 100, 25, "Save All Frames", function()
        {
            if (daSprite.animation.curAnim != null) {
                var folder = 'OUTPUT/${inputArray[curSelected]}';
                if (FileSystem.exists(folder) && FileSystem.isDirectory(folder)) {
                    for (i in FileSystem.readDirectory(folder)) {
                        var path = Path.join([folder, i]);
                        if (!FileSystem.isDirectory(path)) {
                            FileSystem.deleteFile(path);
                        }
                    }
                }
                for (i in daSprite.animation.getAnimationList()) {
                    for (frame in i.frames) {
                        var daFrame = daSprite.frames.frames[frame];
                        saveBitmapFromFrame(daFrame, '${inputArray[curSelected]}/${daFrame.name}', getAnimRect(i));
                    }
                }
                if (FileSystem.exists(folder) && FileSystem.isDirectory(folder) && FileSystem.readDirectory(folder).length > 0) {
                    FlxG.sound.play('assets/sounds/confirmMenu.ogg');
                }
            }
        });
        saveAllFrames.setGraphicSize(Std.int(saveAllFrames.width), Std.int(saveAllFrames.height * 2));
		changeAllLabelsOffset(saveAllFrames, 0, -6);

        var updateSpritesheets:FlxButton = new FlxButton(10, saveFrame.y + 50, "Reload Spritesheets", function()
		{
            MusicBeatState.resetState();
		});
        updateSpritesheets.setGraphicSize(Std.int(updateSpritesheets.width), Std.int(updateSpritesheets.height * 2));
		changeAllLabelsOffset(updateSpritesheets, 0, -6);

        tab_group.add(saveFrame);
        tab_group.add(saveAnim);
        tab_group.add(saveAllFrames);
        tab_group.add(updateSpritesheets);
        UI_box.addGroup(tab_group);
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);

        daSprite.screenCenter();
        
        var blockInput:Bool = false;
        for (stepper in blockPressWhileTypingOnStepper) {
            @:privateAccess
            var leText:Dynamic = stepper.text_field;
            var leText:FlxUIInputText = leText;
            if (leText.hasFocus) {
                FlxG.sound.muteKeys = [];
                FlxG.sound.volumeDownKeys = [];
                FlxG.sound.volumeUpKeys = [];
                blockInput = true;
                break;
            }
        }

		if (!blockInput) {
			FlxG.sound.muteKeys = muteKeys;
			FlxG.sound.volumeDownKeys = volumeDownKeys;
			FlxG.sound.volumeUpKeys = volumeUpKeys;
		}

        if (!blockInput) {
            if (inputArray.length > 1) {
                var controlArray = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT];
                        
                for (i in 0...controlArray.length) {
                    if (controlArray[i]) {
                        var negaMult = -1;
                        if (i % 2 == 1) negaMult = 1;
                        changeSelection(negaMult);
                        FlxG.sound.play('assets/sounds/scrollMenu.ogg');
                    }
                }
            }

            if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
                FlxG.camera.zoom -= elapsed * 3;
                if (FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
            }
            if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
                FlxG.camera.zoom += elapsed * 3;
                if (FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
            }
            if (FlxG.keys.pressed.R) {
                FlxG.camera.zoom = 1;
            }

            if (daSprite.animation.curAnim != null) {
                if (FlxG.keys.justPressed.SPACE) {
                    if (daSprite.animation.finished) {
                        daSprite.animation.play(daSprite.animation.name, true);
                    } else if (daSprite.animation.paused) {
                        daSprite.animation.resume();
                    } else {
                        daSprite.animation.pause();
                    }
                }
                if (daSprite.animation.curAnim.numFrames > 1) {
                    if (FlxG.keys.justPressed.COMMA) {
                        daSprite.animation.pause();
                        if (daSprite.animation.curAnim.curFrame <= 0) {
                            daSprite.animation.curAnim.curFrame = daSprite.animation.curAnim.numFrames - 1;
                        } else {
                            --daSprite.animation.curAnim.curFrame;
                        }
                    }
                    if (FlxG.keys.justPressed.PERIOD) {
                        daSprite.animation.pause();
                        if (daSprite.animation.curAnim.curFrame >= daSprite.animation.curAnim.numFrames - 1) {
                            daSprite.animation.curAnim.curFrame = 0;
                        } else {
                            daSprite.animation.curAnim.curFrame++;
                        }
                    }
                }
                if (currentData != null && currentData.animations.length > 1) {
                    if (FlxG.keys.justPressed.UP) {
                        --curAnimation;
                        if (curAnimation < 0) {
                            curAnimation = currentData.animations.length - 1;
                        }
                        daSprite.animation.play(currentData.animations[curAnimation].name, true);
                    } else if (FlxG.keys.justPressed.DOWN) {
                        curAnimation++;
                        if (curAnimation > currentData.animations.length - 1) {
                            curAnimation = 0;
                        }
                        daSprite.animation.play(currentData.animations[curAnimation].name, true);
                    }
                }
                textAnim.text = '${inputArray[curSelected]}\n${daSprite.animation.name}\n${daSprite.animation.curAnim.curFrame + 1}/${daSprite.animation.curAnim.numFrames}';
            } else {
                textAnim.text = '';
            }

            var controlArray = [FlxG.keys.pressed.A, FlxG.keys.pressed.D, FlxG.keys.pressed.W, FlxG.keys.pressed.S];
                    
            for (i in 0...controlArray.length) {
                if (controlArray[i]) {
                    var holdShift = FlxG.keys.pressed.SHIFT;
                    var multiplier = elapsed * 600;
                    if (holdShift)
                        multiplier = elapsed * 1200;

                    var negaMult = -1;
                    if (i % 2 == 1) negaMult = 1;
                    if (i > 1) {
                        camFollow.y += negaMult * multiplier;
                    } else {
                        camFollow.x += negaMult * multiplier;
                    }
                }
            }

            camFollowPos.setPosition(camFollow.x, camFollow.y);

            if (FlxG.keys.justPressed.ESCAPE) {
				MusicBeatState.switchState(new editors.MasterEditorMenu());
				CoolUtil.playMenuMusic();
			}
        }
    }

    function changeSelection(add:Int = 0) {
        curSelected += add;
        if (curSelected < 0) {
            curSelected = inputArray.length - 1;
        } else if (curSelected > inputArray.length - 1) {
            curSelected = 0;
        }

        makeSprite();
    }

    function getInputs(reloadAll:Bool = false) {
        inputArray = [];
        inputTypes.clear();
        textures.clear();
        var folder:String = 'mods/images/characters';
        if (FileSystem.exists(folder)) {
            for (file in FileSystem.readDirectory(folder)) {
                var path = Path.join([folder, file]);
                if (FileSystem.isDirectory(path) && FileSystem.exists(path + '/Animation.json')) {
                    //trace('texture atlas: $file');
                    inputArray.push(file);
                    inputTypes.set(file, TEXTURE);
                }
            }
            preloadTextures(reloadAll);
            //trace('Gotten inputs: $inputArray');
            //trace('Gotten types: $inputTypes');
        }
        if (!FileSystem.exists('OUTPUT'))
            FileSystem.createDirectory('OUTPUT');
    }

    function makeSprite() {
        if (members.contains(daSprite))
            remove(daSprite, true);

        if (dataMap.exists(inputArray[curSelected])) {
            currentData = dataMap.get(inputArray[curSelected]);
            loadCurrentData();
        }

        daSprite = new FlxSprite();
        reloadSpriteImage();
        daSprite.screenCenter();

        curAnimation = 0;
        daSprite.flipX = flipXCheckBox.checked;
        daSprite.flipY = flipYCheckBox.checked;
        daSprite.antialiasing = !noAntialiasingCheckBox.checked;

        add(daSprite);
    }

    function preloadTextures(reloadAll:Bool = false) {
        if (reloadAll) {
            textures.clear();
        } else {
            for (i in textures.keys()) {
                if (!inputArray.contains(i)) {
                    textures.remove(i);
                }
            }
        }
        for (i in inputArray) {
            switch (inputTypes.get(i)) {
                default:
                    var daFrames = AtlasFrameMaker.construct('characters/$i');
                    textures.set(i, daFrames);
            }
        }
    }

    function reloadSpriteImage() {
        if (inputArray.length > 0 && inputArray[curSelected] != null) {
            var curInput = inputArray[curSelected];
            switch (inputTypes.get(curInput)) {
                default:
                    if (textures.exists(curInput)) {
                        daSprite.frames = textures.get(curInput);
                    } else { //should already be preloaded but just in case
                        trace('HAVING TO MAKE $curInput');
                        daSprite.frames = AtlasFrameMaker.construct('characters/$curInput');
                        textures.set(curInput, daSprite.frames);
                    }
            }

            if (dataMap.exists(curInput)) {
                var data = dataMap.get(curInput);
                for (i in data.animations) {
                    switch inputTypes.get(curInput) {
                        default:
                            daSprite.animation.addByPrefix(i.name, '${i.name}', 24, false);
                    }
                    if (daSprite.animation.curAnim == null) {
                        daSprite.animation.play(i.name);
                    }
                }
            } else {
                var newData:SpritesheetData = {
                    animations: [],
                    flipX: false,
                    flipY: false,
                    noAntialiasing: false,
                    scale: 1
                };
                for (i in AtlasFrameMaker.getFrameLabels('characters/$curInput')) {
                    daSprite.animation.addByPrefix(i, '$i', false);
                    if (daSprite.animation.curAnim == null) {
                        daSprite.animation.play(i);
                    }
                    newData.animations.push({
                        name: i
                    });
                }
                dataMap.set(curInput, newData);
            }
            currentData = dataMap.get(curInput);
            loadCurrentData();
            daSprite.setGraphicSize(Std.int(daSprite.width * scaleStepper.value));
            daSprite.updateHitbox();
        }
    }

    function saveBitmapFromFrame(frame:FlxFrame, file:String, rect:Rectangle) {
        var flipX = flipXCheckBox.checked;
        var flipY = flipYCheckBox.checked;
        if (inputTypes.get(inputArray[curSelected]) != TEXTURE) {
            var bitmap:BitmapData = new BitmapData(Std.int(rect.width), Std.int(rect.height), true, 0);
            frame.paintRotatedAndFlipped(bitmap, null, 0, flipX, flipY);
            var newWidth = Std.int(bitmap.width * scaleStepper.value);
            var newHeight = Std.int(bitmap.height * scaleStepper.value);
            var newBitmap = new BitmapData(newWidth, newHeight, true, 0);
            var matrix = new Matrix();
            matrix.scale(scaleStepper.value, scaleStepper.value);
            newBitmap.draw(bitmap, matrix, null, null, null, !noAntialiasingCheckBox.checked);
            saveImage(newBitmap, file, newBitmap.rect);
        } else {
            var bitmap:BitmapData = new BitmapData(Std.int(rect.width), Std.int(rect.height), true, 0);
            frame.paint(bitmap);
            var newWidth = Std.int(bitmap.width * scaleStepper.value);
            var newHeight = Std.int(bitmap.height * scaleStepper.value);
            var newBitmap = new BitmapData(newWidth, newHeight, true, 0);
            var matrix = new Matrix();
            //THIS IS TAKEN FROM FLXFRAME & FLXMATRIX
            @:privateAccess{
            matrix.a = frame.blitMatrix[0];
            matrix.b = frame.blitMatrix[1];
            matrix.c = frame.blitMatrix[2];
            matrix.d = frame.blitMatrix[3];
            matrix.tx = frame.blitMatrix[4];
            matrix.ty = frame.blitMatrix[5];
            }
            matrix.scale(scaleStepper.value, scaleStepper.value);
            if (flipX) {
                matrix.scale(-1, 1);
                matrix.translate(newWidth, 0);
            }
            if (flipY) {
                matrix.scale(1, -1);
                matrix.translate(0, newHeight);
            }
            newBitmap.draw(bitmap, matrix, null, null, null, !noAntialiasingCheckBox.checked);
            saveImage(newBitmap, file, newBitmap.rect);
        }
    }

    function saveImage(bitmap:BitmapData, file:String, rect:Rectangle) {
        var b:ByteArray = new ByteArray();
        b = bitmap.encode(rect, new PNGEncoderOptions(true), b);
        if (!FileSystem.exists('OUTPUT/${file.substr(0, file.lastIndexOf('/'))}')) {
            FileSystem.createDirectory('OUTPUT/${file.substr(0, file.lastIndexOf('/'))}');
        }
        File.saveBytes('OUTPUT/$file.png', b);
    }

    function changeAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets)
		{
			point.set(point.x + x, point.y + y);
		}
	}

    function getAnimRect(anim:FlxAnimation):Rectangle {
        /*if (inputTypes.get(inputArray[curSelected]) != TEXTURE) {
            return null;
        }*/
        //IF I DONT DO THIS TEXTURE ATLASES AREN'T CROPPED PROPERLY???
        var maxWidth:Float = Math.NEGATIVE_INFINITY;
        var maxHeight:Float = Math.NEGATIVE_INFINITY;
        for (i in anim.frames) {
            var frame = daSprite.frames.frames[i];
            if (frame.frame.width + frame.offset.x > maxWidth) {
                maxWidth = frame.frame.width + frame.offset.x;
            }
            if (frame.frame.height + frame.offset.y > maxHeight) {
                maxHeight = frame.frame.height + frame.offset.y;
            }
        }
        return new Rectangle(0, 0, maxWidth, maxHeight);
    }

    function saveCurrentData() {
        if (currentData != null) {
            currentData.flipX = flipXCheckBox.checked;
            currentData.flipY = flipYCheckBox.checked;
            currentData.noAntialiasing = noAntialiasingCheckBox.checked;
            currentData.scale = scaleStepper.value;

            dataMap.set(inputArray[curSelected], currentData);
        }
    }

    function loadCurrentData() {
        if (currentData != null) {
            flipXCheckBox.checked = currentData.flipX;
            flipYCheckBox.checked = currentData.flipY;
            noAntialiasingCheckBox.checked = currentData.noAntialiasing;
            scaleStepper.value = currentData.scale;
        }
    }
}