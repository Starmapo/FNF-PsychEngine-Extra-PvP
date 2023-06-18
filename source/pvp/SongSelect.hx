package pvp;

import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.FlxG;
import flixel.tweens.FlxTween;
import flixel.text.FlxText;
import flixel.FlxSprite;
import pvp.PvPSongState.SongMetadata;
import flixel.group.FlxSpriteGroup;

class SongSelect extends FlxSpriteGroup {
    public var songs:Array<SongMetadata> = [];
    public var isGamepad:Bool = false;
    public var id:Int = 0;
    public var difficulties:Array<String> = ['Easy', 'Normal', 'Hard'];
    public var ready:Bool = false;

    public var curSelected:Int = 0;
	public var curDifficulty:Int = -1;
	private var lastDifficultyName:String = '';
    public var storyWeek:Int = 0;

    var scoreBG:FlxSprite;
	var diffText:FlxText;

    private var grpSongs:FlxTypedSpriteGroup<FlxText>;
	private var grpIcons:FlxTypedSpriteGroup<HealthIcon>;

	private var iconArray:Array<HealthIcon> = [];

    var bg:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;

    var noGamepadBlack:FlxSprite;
    var noGamepadText:FlxText;
    var noGamepadSine:Float = 0;

    public function new(x:Float = 0, y:Float = 0, songs:Array<SongMetadata>, isGamepad:Bool = false) {
        super(x, y);
        this.songs = songs.copy();
        this.isGamepad = isGamepad;
        id = (isGamepad ? 0 : 1);

        bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.globalAntialiasing;
        bg.scrollFactor.set();
        var daClipRect = new FlxRect((!isGamepad ? FlxG.width / 2 : 0), 0, FlxG.width / 2, bg.frameHeight);
        bg.clipRect = daClipRect;
        add(bg);
        bg.x = 0;

        grpSongs = new FlxTypedSpriteGroup();
		add(grpSongs);
		grpIcons = new FlxTypedSpriteGroup();
		add(grpIcons);

        if (PvPSongState.lastSelected[id] != null)
            curSelected = PvPSongState.lastSelected[id];
		if (curSelected >= songs.length)
            curSelected = 0;
		regenMenu(false);

        scoreBG = new FlxSprite((FlxG.width / 2) * 0.7 - 6, 0).makeGraphic(195, 24, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(0, 0, 0, "", 24);
		diffText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
        diffText.x = Std.int((scoreBG.x + (scoreBG.width / 2)) - (diffText.width / 2));
		add(diffText);

        if (isGamepad) {
            noGamepadBlack = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width / 2), 720, FlxColor.BLACK);
            noGamepadBlack.scrollFactor.set();
            noGamepadBlack.alpha = 0.8;
            noGamepadBlack.visible = (FlxG.gamepads.lastActive == null);
            add(noGamepadBlack);

            noGamepadText = new FlxText(0, 360 - 16, FlxG.width / 2, "Waiting for gamepad...", 32);
            noGamepadText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            noGamepadText.scrollFactor.set();
            noGamepadText.borderSize = 2;
            noGamepadText.visible = (FlxG.gamepads.lastActive == null);
            add(noGamepadText);
        }

        if (songs.length > 0)
            bg.color = songs[curSelected].color;
		intendedColor = bg.color;

        if (PvPSongState.lastDiff[id] == null) {
            lastDifficultyName = CoolUtil.defaultDifficulty;
            curDifficulty = FlxMath.maxInt(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName));
        } else {
            lastDifficultyName = PvPSongState.lastDiffName[id];
            curDifficulty = PvPSongState.lastDiff[id];
        }

        setClipRect();
        changeSelection();
    }

    var holdTime:Float = 0;
    override function update(elapsed:Float) {
        super.update(elapsed);

        var bullShit:Int = 0;
        var lerpVal:Float = CoolUtil.boundTo(elapsed * 9.6, 0, 1);
        for (i in 0...grpSongs.length) {
            var item = grpSongs.members[i];
            var targetY = bullShit - curSelected;
            var scaledY = FlxMath.remapToRange(targetY, 0, 1, 0, 1.3);
            item.y = FlxMath.lerp(item.y, (scaledY * 80) + (FlxG.height * 0.48), lerpVal);
            item.x = FlxMath.lerp(item.x, (targetY * 20) + 90 + (!isGamepad ? FlxG.width / 2 : 0), lerpVal);
            bullShit++;

            if (targetY == 0)
                item.alpha = 1;
            else if (!ready)
                item.alpha = 0.6;
            else
                item.alpha = 0;

            iconArray[i].y = item.y - 15;
        }

        if (!PvPSongState.exiting) {
            var controls = PlayerSettings.player1.controls;
            var upP = controls.UI_UP_P;
            var downP = controls.UI_DOWN_P;
            var leftP = controls.UI_LEFT_P;
            var rightP = controls.UI_RIGHT_P;
            var up = controls.UI_UP;
            var down = controls.UI_DOWN;
            var accepted = controls.ACCEPT;
            var back = controls.BACK;

            if (isGamepad) {
                var gamepad = FlxG.gamepads.lastActive;
                if (gamepad != null) {
                    noGamepadBlack.visible = false;
                    noGamepadText.visible = false;
                    upP = (gamepad.justPressed.LEFT_STICK_DIGITAL_UP || gamepad.justPressed.DPAD_UP);
                    downP = (gamepad.justPressed.LEFT_STICK_DIGITAL_DOWN || gamepad.justPressed.DPAD_DOWN);
                    leftP = (gamepad.justPressed.LEFT_STICK_DIGITAL_LEFT || gamepad.justPressed.DPAD_LEFT);
                    rightP = (gamepad.justPressed.LEFT_STICK_DIGITAL_RIGHT || gamepad.justPressed.DPAD_RIGHT);
                    up = (gamepad.pressed.LEFT_STICK_DIGITAL_UP || gamepad.pressed.DPAD_UP);
                    down = (gamepad.pressed.LEFT_STICK_DIGITAL_DOWN || gamepad.pressed.DPAD_DOWN);
                    accepted = (gamepad.justPressed.A);
                    back = (gamepad.justPressed.B);
                } else {
                    noGamepadBlack.visible = true;
                    noGamepadText.visible = true;
                    up = false;
                    down = false;
                    upP = false;
                    downP = false;
                    leftP = false;
                    rightP = false;
                    accepted = false;
                    back = false;
                }
            }

            var shiftMult:Int = 1;
            if (!isGamepad && FlxG.keys.pressed.SHIFT) shiftMult = 3;

            if (!ready) {
                if (songs.length > 1)
                {
                    if (upP)
                    {
                        changeSelection(-shiftMult);
                        holdTime = 0;
                    }
                    if (downP)
                    {
                        changeSelection(shiftMult);
                        holdTime = 0;
                    }

                    if (down || up)
                    {
                        var checkLastHold:Int = Math.floor((holdTime - 0.5) * 20);
                        holdTime += elapsed;
                        var checkNewHold:Int = Math.floor((holdTime - 0.5) * 20);

                        if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
                        {
                            changeSelection((checkNewHold - checkLastHold) * (up ? -shiftMult : shiftMult));
                            changeDiff();
                        }
                    }
                }

                if (songs.length > 0 && difficulties.length > 1) {
                    if (leftP)
                        changeDiff(-1);
                    else if (rightP)
                        changeDiff(1);
                }
            }

            if (back)
            {
                if (!ready) {
                    var gamepad = FlxG.gamepads.lastActive;
                    if (gamepad != null)
                        controls.addDefaultGamepad(0);

                    PvPSongState.exiting = true;
                    if (colorTween != null)
                        colorTween.cancel();
                    CoolUtil.playCancelSound();
                    MusicBeatState.switchState(new MainMenuState());
                    CoolUtil.playMenuMusic();
                } else
                    playerUnready();
            }

            if (songs.length > 0 && accepted && !ready)
                playerReady();
        }

        setClipRect();

        if (isGamepad && noGamepadText.visible) {
            noGamepadSine += 180 * elapsed;
            noGamepadText.alpha = 1 - Math.sin((Math.PI * noGamepadSine) / 180);
        }
    }

    function playerReady() {
        ready = true;
        for (i in 0...grpSongs.length) {
            var item = grpSongs.members[i];
            if (item.alpha < 1) {
                item.alpha = 0;
                iconArray[i].alpha = 0;
            }
        }
        CoolUtil.playConfirmSound();
    }

    function playerUnready() {
        ready = false;
        for (i in 0...grpSongs.length) {
            var item = grpSongs.members[i];
            var daAlpha = (i == curSelected ? 1 : 0.6);
            item.alpha = daAlpha;
            iconArray[i].alpha = (i == 0 ? 0 : daAlpha);
        }
        CoolUtil.playCancelSound();
    }

    private function positionHighscore() {
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

    function difficultyString():String
	{
		return difficulties[curDifficulty].toUpperCase();
	}

    function changeDiff(change:Int = 0)
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = difficulties.length - 1;
		if (curDifficulty >= difficulties.length)
			curDifficulty = 0;

        if (songs[curSelected].random) {
            curDifficulty = 0;
            lastDifficultyName = '';
            diffText.text = '';
        } else {
            lastDifficultyName = difficulties[curDifficulty];

            if (difficulties.length > 1) {
                diffText.text = '< ${difficultyString()} >';
            } else {
                diffText.text = difficultyString();
            }
            positionHighscore();
        }
        PvPSongState.lastDiff[id] = curDifficulty;
        PvPSongState.lastDiffName[id] = lastDifficultyName;
	}

    function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (playSound) CoolUtil.playScrollSound();

		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;
		
		if (songs.length > 0) {
			var newColor:Int = songs[curSelected].color;
			if (newColor != intendedColor) {
				if (colorTween != null) {
					colorTween.cancel();
				}
				intendedColor = newColor;
				colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
					onComplete: function(twn:FlxTween) {
						colorTween = null;
					}
				});
			}

			for (i in 0...iconArray.length)
				iconArray[i].alpha = (songs[i].random ? 0 : 0.6);

			if (iconArray[curSelected] != null && !songs[curSelected].random)
				iconArray[curSelected].alpha = 1;

			storyWeek = songs[curSelected].week;
			
            if (songs[curSelected].difficulties == null) {
			    CoolUtil.getDifficulties(songs[curSelected].songName, true);
                difficulties = CoolUtil.difficulties.copy();
            } else
                difficulties = songs[curSelected].difficulties.split(',');
		}

		if(difficulties.contains(CoolUtil.defaultDifficulty))
			curDifficulty = FlxMath.maxInt(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty));
		else
			curDifficulty = 0;

		var newPos:Int = difficulties.indexOf(lastDifficultyName);
		if (newPos < 0) newPos = difficulties.indexOf(lastDifficultyName.charAt(0).toUpperCase() + lastDifficultyName.substr(1));
		if (newPos < 0) newPos = difficulties.indexOf(lastDifficultyName.toLowerCase());
		if (newPos < 0) newPos = difficulties.indexOf(lastDifficultyName.toUpperCase());
		if (newPos > -1)
		{
			curDifficulty = newPos;
		}
		changeDiff();
        PvPSongState.lastSelected[id] = curSelected;
	}

    public function selectRandom() {
        curSelected = FlxG.random.int(1, songs.length - 1);
        storyWeek = songs[curSelected].week;
        if (songs[curSelected].difficulties == null) {
            CoolUtil.getDifficulties(songs[curSelected].songName, true);
            difficulties = CoolUtil.difficulties.copy();
        } else
            difficulties = songs[curSelected].difficulties.split(',');
        curDifficulty = FlxG.random.int(0, difficulties.length - 1);
    }

    function regenMenu(change:Bool = true) {
		for (i in 0...grpSongs.members.length) {
			var obj = grpSongs.members[0];
			obj.kill();
			grpSongs.remove(obj, true);
			obj.destroy();
		}
		for (i in 0...grpIcons.members.length) {
			var obj = grpIcons.members[0];
			obj.kill();
			grpIcons.remove(obj, true);
			obj.destroy();
		}
		iconArray = [];
		for (i in 0...songs.length)
		{
			var songText = new FlxText(0, (35 * i) + 15, 0, songs[i].displayName, 32);
            songText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
            if (175 + songText.width > 640)
            {
                var textScale:Float = (465 / songText.width);
                songText.size = Math.round(songText.size * textScale);
            }
            songText.borderSize = 2;

            var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
            icon.scale.set(0.5, 0.5);
            updateIconHitbox(icon);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			grpIcons.add(icon);
            grpSongs.add(songText);
		}
		if (change)
			changeSelection(0, false);
	}

    function updateIconHitbox(icon:HealthIcon) {
        icon.updateHitbox();
        icon.offset.set((-0.5 * (icon.width - icon.frameWidth)) + (icon.iconOffsets[0] * icon.scale.x), (-0.5 * (icon.height - icon.frameHeight)) + (icon.iconOffsets[1] * icon.scale.y));
    }

    function setClipRect() {
        var sprites:Array<FlxSprite> = [];
        for (spr in grpSongs)
            sprites.push(spr);
        for (spr in grpIcons)
            sprites.push(spr);
        for (spr in sprites) {
            var isAttached = false;
            if (Std.isOfType(spr, HealthIcon)) {
                var spr:HealthIcon = cast spr;
                if (spr.sprTracker != null && spr.sprTracker.active)
                    isAttached = true;
            }
            if (!isAttached && (spr.x + spr.width < x || spr.x > x + (FlxG.width / 2))) {
                spr.visible = false;
                spr.active = false;
            } else {
                spr.visible = true;
                spr.active = true;
                var swagRect = new FlxRect(0, 0, spr.frameWidth, spr.frameHeight);
                if (spr.x < x) {
                    swagRect.x += Math.abs(x - spr.x) / spr.scale.x;
                    swagRect.width -= swagRect.x;
                    spr.clipRect = swagRect;
                } else if (spr.x + spr.width > x + (FlxG.width / 2)) {
                    swagRect.width -= ((spr.x + spr.width) - (x + (FlxG.width / 2))) / spr.scale.x;
                    spr.clipRect = swagRect;
                }
                spr.clipRect = swagRect;
            }
        }
    }
}