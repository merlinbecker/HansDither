## 1\. What is Playdate?

Playdate is a curious handheld gaming console.

Playdate players collectively share the experience of a curated selection of video games made by independent developers, revealed one at a time on a fixed schedule. A collection of these games is known as a "season", analogous to a season of a television show.

Playdate developers write their games using the simple scripting language Lua, and asset creation tools they are already familiar with.

### [Link to this](http://sdk.play.date/inside-playdate/\#_playdate_specifications "Link to this") 1.1. Playdate specifications

Display

- Monochrome (1-bit) memory LCD display

- 400 x 240 pixel resolution

- Refreshed at 30 frames-per-second (fps) by default, maximum 50 fps


Controls

- Eight-way directional control (D-pad)

- Two primary buttons

- Menu button

- Lock button

- Collapsible crank

- Accelerometer


Sound

- Internal speaker

- Microphone

- Headphone jack supporting mic input


Connectivity

- Wi-Fi

- Bluetooth


Memory & Storage

- 16MB RAM

- 4GB flash storage


### [Link to this](http://sdk.play.date/inside-playdate/\#_playdate_hardware_naming_conventions "Link to this") 1.2. Playdate hardware naming conventions

![playdate definitions](http://sdk.play.date/Inside%20Playdate/playdate-definitions.png)

Figure 1. A Playdate and the name of its components.

Lock button

The top-edge metal button, which sleeps and wakes the system. Referred to as the capital-L "Lock button".

Menu button

The top-right button on the face of the device, with a dot in its center. This presents the System Menu. Referred to as the capital-M "Menu button".

D-pad

The D is capitalized if the term is at the beginning of the sentence; otherwise, it is "d-pad".

A button/B button

"A" and "B" are capitalized; the "b" in "button" is not.

Crank

The action of taking out the crank is called _extending_ the crank. Putting it away is _stowing_ the crank. If the crank is turned in the direction shown in the illustration below, it is said to be turning _forward_. The opposite direction is _backward_.

![crank rotation](http://sdk.play.date/Inside%20Playdate/crank-rotation.png)

Figure 2. Playdate cranking direction.

## 2\. Contents of the SDK

This SDK contains:

- Software tools to compile your game

- A device Simulator to test your game

- A set of libraries for common functions you can use in your game

- Some fonts and other assets you can use in your game

- Some example code and games

- Documentation


## 3\. Installation

After [downloading the SDK](https://play.date/dev/) for your desired platform you will need to complete the installation:

- MacOS: Run the SDK installer application

- Windows: Extract the SDK and run the SDK installer application

- Linux



1. Extract the SDK folder archive

2. Move the SDK folder to your desired user-writable location

3. Run the `setup.sh` script inside the SDK folder to complete the installation


## 4\. Writing a game

### [Link to this](http://sdk.play.date/inside-playdate/\#_choosing_your_development_language "Link to this") 4.1. Choosing your development language

Most Playdate games are [written in Lua](http://sdk.play.date#developing-in-lua) for ease of development, but games with the strictest performance needs can be [written partially or entirely in C](http://sdk.play.date#developing-in-c). See the associated sections for information on which might be the right choice for you.

[[4.2 Structuring your project]]
### [Link to this](http://sdk.play.date/inside-playdate/\#_compiling_a_project "Link to this") 4.3. Compiling a project

Playdate projects are compiled with the command line tool **`pdc`** (for "Playdate Compiler").

#### [Link to this](http://sdk.play.date/inside-playdate/\#_set_playdate_sdk_path_environment_variable "Link to this") Set `PLAYDATE_SDK_PATH` Environment Variable

On **macOS**, it is recommended, but not required.

On **Linux**, it is required for CMake and Make files, and recommended for Lua projects.

On **Windows**, it is required for CMake files (see the _Building on Windows_ section in the [**_Inside Playdate for C_**](http://sdk.play.date#developing-in-c) docs for instructions), and recommended for Lua projects

Add the following line to your shell’s startup file ( _~/.bash\_profile_ or _~/.bashrc_ for **bash**, or _~/.zprofile_ if you use **zsh**, etc.). Replace `<path to SDK>` placeholder text with the SDK location:

```
export PLAYDATE_SDK_PATH=<path to SDK>
```

|     |     |
| --- | --- |
| Note | The **`pdc`** compiler will use this value for the default location of the SDK if it is not specified using the `-sdkpath` flag. |

|     |     |
| --- | --- |
| Tip | You may also want to add `<path to SDK>/bin` to your shell `$PATH` variable. This allows running `pdc`, `pdutil` and the Simulator from any location without a fully qualified path. |

**`pdc`** requires two arguments: the input (source) directory, and an output directory.

```
$ pdc MyGameSource MyGame.pdx
```

The output directory, by convention, should end with the extension _.pdx_. This directory will appear as a single-icon bundle in Finder. It will contain the compiled source as well as any files that weren’t recognized as Lua source, such as images, sounds, or data files.

Passing the `-s` option to **`pdc`** will strip debugging information from the output files.

To specify folders outside of the project source folder or the SDK as locations for files to be imported, you can set the `PLAYDATE_LIB_PATH` environment variable, or pass them in using the `-I` or `--libpath` command-line flag.

```
$ export PLAYDATE_LIB_PATH=~/pddev/Libs
$ pdc -I ~/pddev/OtherLibs MyGameSource MyGame.pdx
```

In this case, **`pdc`** will first search the `MyGameSource` folder, then the `OtherLibs` folder, then `Libs`, and finally the SDK folder when locating files via the `import` command.

A few other helpful command line arguments:

```
-v/--verbose: verbose mode, gives info about what the compiler is doing
-q/--quiet: quiet mode, suppresses non-error output
-k/--skip-unknown: skip unrecognized files instead of copying them to the pdx folder
```

And finally, to tell **`pdc`** to ignore specific files or folders (other than expected files like main.lua) in the source folder, add it to a file called `.pdcignore` in the source folder; e.g.

```
images/logo.bak.png
test
```

will keep both the file `logo-old.png` in the `images` subfolder and the entire `test` folder from getting compiled. Empty lines and lines starting with `#` are ignored. Wildcard/regex is not currently supported.

### [Link to this](http://sdk.play.date/inside-playdate/\#using-playdate-simulator "Link to this") 4.4. Using the Playdate Simulator

The **Playdate Simulator** is an application that mimics the Playdate device, and makes Playdate development quick and easy. The Simulator not only runs Playdate applications, but can also emulate the functionality of Playdate’s controls, including its crank and accelerometer.

Games running in the Simulator can be controlled by the on-screen GUI, or keyboard equivalents. The Simulator can also be controlled by a select number of a compatible game controllers or the Playdate console itself, if connected.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_running_your_game "Link to this") Running your game

To run your game, take one of these three approaches:

1. Launch the Playdate Simulator app.



- Do one of the following to choose which game to run:



- Choose **Open** from the **File** menu to select the _.pdx_ folder you’d like to run.

- Drag your _.pdx_ folder onto the Simulator window.


2. Double-click on a _.pdx_ folder.

3. If you’re using Nova as your development environment, press Command+R to launch the Simulator and start your game.


|     |     |
| --- | --- |
| Caution | Game performance is considerably faster in the Simulator than on the Playdate hardware. Please take that into consideration when developing your game, and make sure to periodically test on Playdate hardware. |

#### [Link to this](http://sdk.play.date/inside-playdate/\#_running_your_game_on_playdate_hardware "Link to this") Running your game on Playdate hardware

1. Attach your Playdate to your computer via USB cable.

2. Turn on your Playdate by pushing the **_Unlock_** button on top.

3. Run your game in the Playdate Simulator.

4. Choose **Upload Game to Device** from the Simulator’s **Device** menu. After the game is uploaded to your Playdate, it will start running automatically.


|     |     |
| --- | --- |
| Note | If you do not see a **Device** menu in the Simulator’s menubar, check to ensure your Playdate is _unlocked_ (via the metal button on top of Playdate), _powered_, and _properly connected_ to your computer via USB cable. |

#### [Link to this](http://sdk.play.date/inside-playdate/\#_using_your_playdate_to_control_the_simulator "Link to this") Using your Playdate to control the Simulator

If you enjoy the rapid development the Playdate Simulator offers, while also wanting the tactile feel of Playdate controls, you can put your Playdate device into _controller mode_ to control the Simulator with your Playdate hardware.

1. Attach your Playdate to your computer via USB cable.

2. Unlock your Playdate by pushing the metal _Lock_ button on Playdate’s top edge.

3. Press the button with the little Playdate on it that will appear in the lower right corner of the Simulator window.

4. Choose **Use Device as Controller** in the menu that appears. Your Playdate’s inputs will now control the Simulator.


![device menu](http://sdk.play.date/Inside%20Playdate/device-menu.png)

Figure 3. The Playdate Simulator’s "Device" menu.

|     |     |
| --- | --- |
| Note | If you do not see a button with a Playdate icon on the lower edge of the Simulator window, check to ensure your Playdate is _unlocked_ (via the metal button on top of Playdate), _powered_, and _properly connected_ to your computer via USB cable. |

### [Link to this](http://sdk.play.date/inside-playdate/\#usingNova "Link to this") 4.5. Using the Nova extension

Mac users with Nova installed can make use of additional features provided by the Playdate extension. It offers syntax highlighting, autocompletion for Playdate API and allows you to compile, run and debug your project in the Simulator with a single keypress.

To install the extension:

1. Install Nova on your Mac.

3. Click the "Install" button on the web page.


The best way to develop for Playdate using Nova is to create a Project for each Playdate game.

1. After creating your project, click on the project name in the top left of the window tooolbar.

2. In the **Build & Run** section of the resulting dialog, click the **plus (+)** button.

3. Choose **Playdate Simulator** from the list of options to create a new configuration.

4. Specify our project’s _Source_ folder. If it is the default _./Source_ or _./source_, then you don’t need to do anything.

5. Click **Done** to finish.

6. Press the **Run** (▶️) button in the upper left corner of the window to invoke the Playdate Simulator and run your game. (Make sure you have a _main.lua_ file in your project.)


### [Link to this](http://sdk.play.date/inside-playdate/\#pdxinfo "Link to this") 4.6. Game metadata

If a file named **_pdxinfo_** is present at the root of your project’s source directory, it will be used by the system to gather information about your game.

Here is a sample _pdxinfo_ file:

Sample pdxinfo file

```
name=b360
author=Panic Inc.
description=When all you have is a ton of bricks, everything looks like a paddle.
bundleID=com.panic.b360
version=1.0
buildNumber=123
imagePath=path/to/launcher/assets
launchSoundPath=path/to/launch/sound/file
contentWarning=This game contains mild realistic violence and bloodshed.
contentWarning2=This game contains flashing content that may not be suitable for photosensitive epilepsy.
```

The compiler will automatically copy your game’s metadata from your project folder into the resulting game. The contents of the _pdxinfo_ file are accessible via [`playdate.metadata`](http://sdk.play.date#f-metadata).

|     |     |
| --- | --- |
| Note | Image files are compiled to Playdate _.pdi_ files by the `pdc` compiler. When referencing images use no extension or the _.pdi_ extension. |

bundleID

A unique identifier for your game, in reverse DNS notation.

version

A game version number, formatted any way you wish, that is displayed to players. It is not used to compute when updates should occur.

buildNumber

A monotonically-increasing integer value used to indicate a unique version of your game. This can be set using an automated build process like Continuous Integration to avoid having to set the value by hand.

|     |     |
| --- | --- |
| Important | For sideloaded games, `buildNumber` is required and is used to determine when a newer version is available to download. |

imagePath

A _directory of images_ that will be used by the launcher.

Images should be named as follows:

_card.png_

The game’s main card image, visible in the launcher when the view mode is set to "cards". Must be 350 x 155 pixels.

_card-highlighted/_

A folder of images that will be played in a loop when your game is selected in the launcher when the view mode is set to "cards". Images should be named `1.png`, `2.png`, etc. Each image must be 350 x 155 pixels. This folder can optionally contain a text file called `animation.txt` with the format:

animation.txt

```
loopCount = 2
frames = 1, 2, 3x4, 4x2, 5, 5
introFrames = 1, 2x2, 3, 4x2
```

All three lines are optional. `loopCount` indicates the number of times the animation will repeat (indefinitely by default). `frames` is the sequence in which the frames will be shown. Add an `x#` after the frame image number to repeat the image for multiple animation frames. `introFrames` is a sequence of frames that will play once before the `frames` sequence begins, when the card is first highlighted. If a frame sequence is not specified, images will play in order from 1 to the last sequentially numbered image found.

_card-pressed.png_

Displayed on A button down in the launcher when the view mode is set to "cards". Must be 350 x 155 pixels.

_icon.png_

The game’s main icon image, visible in the launcher when the view mode is set to "list". Must be 32 x 32 pixels.

_icon-highlighted/_

A folder of images that will be played in a loop when your game is selected in the launcher when the view mode is set to "list". Images should be named `1.png`, `2.png`, etc. Each image must be 32 x 32 pixels. This folder can optionally contain a text file called `animation.txt` with same format as described for _card-highlighted_.

_icon-pressed.png_

Displayed on A button down in the launcher when the view mode is set to "list". Must be 32 x 32 pixels.

_launchImage.png_

An image that displays while your game is loading, before it is responsive, when the launcher is set to "card" view mode, or in "list" view mode if _launchImage-list.png_ is not provided. Must be fullscreen 400 x 240 pixels, and should not contain transparency. In "card" view mode, this image will be used as the last frame in the game launch animation, if _launchImages/_ are provided.

_launchImage-list.png_

An image that displays while your game is loading, before it is responsive, when the launcher is set to "list" view mode. Must be fullscreen 400 x 240 pixels, and should not contain transparency.

_launchImages/_

A folder of images (named _1.png_, _2.png_, …) that will be played as a transition animation at 20 frames per second when your game is launched when the view mode in the launcher is set to "cards".

Images can contain transparency, but should all be 400 x 240 pixels. See the provided sample game _Level 1-1_ for an example. Before the game launch animation your game’s card image (or _card-highlighted_, or _card-pressed_ image, if available) is drawn by the launcher centered on the screen, drawn in the rect (25, 43, 350, 155) so your animation should assume that image with transparent surrounding space as a starting frame.

_wrapping-pattern.png_

Optional, but if present, will be used as the pattern for the wrapping paper on newly-downloaded games that have yet to be unwrapped. The image dimensions should be 400 x 240 pixels. ( [Template files](http://sdk.play.date/./Inside%20Playdate/wrapping-pattern-templates.zip) are available to help you design the wrapping-paper art for your game. This functionality can be tested in the simulator by selecting "Wrap Current Game" from the Playdate menu.)

At minimum, all games should include **_card.png_**, **_icon.png_** _and a **\_launchImage.png**_ which will be displayed as the system loads the game.

launchSoundPath

_Optional._ Should point to the path of a short audio file to be played as the game launch animation is taking place.

contentWarning

_Optional._ A content warning that displays when the user launches your game for the first time. The user will have the option of backing out and not launching your game if they choose.

contentWarning2

_Optional._ A _second_ content warning that displays on a second screen when the user launches your game for the first time. The user will have the option of backing out and not launching your game if they choose. Note: `contentWarning2` will only display if a `contentWarning` attribute is also specified.

|     |     |
| --- | --- |
| Caution | The string displayed on the content warning screen can only be so long before it will be truncated with an "…" character. Be sure to keep this in mind when designing your `contentWarning` and `contentWarning2` text. |

![Content warning displayed on Playdate screen](http://sdk.play.date/Inside%20Playdate/content-warning.png)

Figure 4. Content warning displayed on a Playdate’s screen.

### [Link to this](http://sdk.play.date/inside-playdate/\#saving-state "Link to this") 4.7. Saving game state

In most games, your users will expect that if they exit your game and come back, they’ll find the game in the same — or similar — state as when they left it.

To implement basic state saving functionality, do the following:

1. Write a function that saves pertinent game data into a table.

3. Implement the functions [playdate.gameWillTerminate()](http://sdk.play.date#c-gameWillTerminate) and [playdate.deviceWillSleep()](http://sdk.play.date#c-deviceWillSleep) and invoke your `saveGameData` function in each.

4. Write code that executes near the beginning of your game that will load game state data from your [datastore](http://sdk.play.date#M-datastore) into a table. Populate your game structures with the saved data in the table.


An example of basic state saving functionality

```
-- Some examples of game data
local level = 1
local health = 100

-- Function that saves game data
function saveGameData()
    -- Save game data into a table first
    local gameData = {
        currentLevel = level,
        currentHealth = health
    }
    -- Serialize game data table into the datastore
    playdate.datastore.write(gameData)
end

-- Automatically save game data when the player chooses
-- to exit the game via the System Menu or Menu button
function playdate.gameWillTerminate()
    saveGameData()
end

-- Automatically save game data when the device goes
-- to low-power sleep mode because of a low battery
function playdate.gameWillSleep()
    saveGameData()
end

-- Call near the start of your game to load saved data
local gameData = playdate.datastore.read()
-- If game data has never been saved, the read value will
-- be 'nil', so check if the game data exists first
if gameData then
    -- Populate game structures with the saved data
    level = gameData.currentLevel
    health = gameData.currentHealth
end
```

### [Link to this](http://sdk.play.date/inside-playdate/\#localization "Link to this") 4.8. Localization

Localization in Playdate is achieved through the use of string lookup files. Currently, English and Japanese are supported. The files should be called _en.strings_ and _jp.strings_ respectively and should be placed in the root of the game’s _source_ folder.

The format of a _.strings_ file is as follows:

Sample en.strings file

```
"greeting" = "Howdy"
"farewell" = "Goodbye"
-- comments are allowed
"video game" = "video game"
```

The corresponding _jp.strings_ file would be:

Sample jp.strings file

```
"greeting" = "こんにちは"
"farewell" = "さようなら"
-- comments are allowed
"video game" = "ビデオゲーム"
```

Refer to the API reference for how to retrieve or draw localized text.

### [Link to this](http://sdk.play.date/inside-playdate/\#_game_size "Link to this") 4.9. Game size

Playdate has 4GB of flash storage. While that is a decent amount, it isn’t inexhaustible.

What’s a good size for a Playdate game? From what we’ve seen so far, a typical Playdate game might be in the 20-40MB range. Some — primarily those that use synthesized audio — are much smaller, even less than 100KB. Large games with a lot of audio can grow to be 100MB or more.

Out of respect for Playdate owners, we ask that you try to keep your games closer to that average size of 20-40MB. (Of course, you can make your game as big as you want — and maybe there is some spectacular 400MB game out there just waiting to be written. Shy of that, however, we — and the Playdate owners you’re targeting — would prefer it if you keep the size down.)f

The biggest culprit in blowing up game size is **_audio_**. If your game is large due to the inclusion of a lot of audio, we recommend:

1. Ensuring your audio is compressed. [See here for some tips](http://sdk.play.date#M-sound-prep).

2. If your audio is already compressed, consider [synthesized audio](http://sdk.play.date#C-sound.synth), using the rich set of APIs provided. Or consider simply using less audio.


[[## 5. Developing in Lua]]


## 6\. Developing in C

If your Playdate game requires maximum performance, C is the best choice.

Parts of your game, or the entire game if desired, can be written in C using the Playdate C API. For details, see [Inside Playdate with C](http://sdk.play.date/./Inside%20Playdate%20with%20C.html). There are also a few examples in the C\_API/Examples folder that should help get you started.

We are still in the process of adding more functions to the C API, and creating more examples.

## 7\. API reference

### [Link to this](http://sdk.play.date/inside-playdate/\#playdate-sdk-lua-enhancements "Link to this") 7.1. Playdate SDK Lua enhancements

#### [Link to this](http://sdk.play.date/inside-playdate/\#additional-assignment-operators "Link to this") Additional assignment operators

Lua does not by default support assignment operators like `+=` and `-=` that are common in other languages. As a convenience for developers, the Playdate SDK adds the following:

|     |     |
| --- | --- |
| `+=` | Addition |
| `-=` | Subtraction |
| `*=` | Multiplication |
| `/=` | Division |
| `//=` | Integer division |
| `%=` | Modulo |
| `<<=` | Shift left |
| `>>=` | Shift right |
| `&=` | Bitwise AND |
| `|=` | Bitwise OR |
| `^=` | Exponent (not bitwise XOR) |

#### [Link to this](http://sdk.play.date/inside-playdate/\#table-additions "Link to this") Table additions

The Playdate SDK offers some convenience functions for handling Lua tables, beyond what is available in Lua itself:

[Link to this](http://sdk.play.date/inside-playdate/#t-table.indexOfElement "Link to this")

table.indexOfElement(table, element)

Returns the first index of _element_ in the given array-style table. If the table does not contain _element_, the function returns nil.

[Link to this](http://sdk.play.date/inside-playdate/#t-table.getsize "Link to this")

table.getsize(table)

Returns the size of the given table as multiple values ( _arrayCount_, _hashCount_).

[Link to this](http://sdk.play.date/inside-playdate/#t-table.create "Link to this")

table.create(arrayCount, hashCount)

Returns a new Lua table with the array and hash parts preallocated to accommodate _arrayCount_ and _hashCount_ elements respectively.

|     |     |
| --- | --- |
| Tip | If you can make a decent estimation of how big your table will need to be, `table.create()` can be much more efficient than the alternative, especially in loops. For example, if you know your array is always going to contain approximately ten elements, say `myArray = table.create( 10, 0 )` instead of `myArray = {}`. |

[Link to this](http://sdk.play.date/inside-playdate/#t-table.shallowcopy "Link to this")

table.shallowcopy(source, \[destination\])

`shallowcopy` returns a shallow copy of the _source_ table. If a _destination_ table is provided, it copies the contents of _source_ into _destination_ and returns _destination_. The copy will contain references to any nested tables.

[Link to this](http://sdk.play.date/inside-playdate/#t-table.deepcopy "Link to this")

table.deepcopy(source)

`deepcopy` returns a deep copy of the _source_ table. The copy will contain copies of any nested tables.

[Link to this](http://sdk.play.date/inside-playdate/#f-apiVersion "Link to this")

playdate.apiVersion()

Returns two values, the current API version of the Playdate runtime and the minimum API version supported by the runtime.

### [[7.3 Game Flow]]
### [[7.4 Game lifecycle]]
### [[7.5 Interacting with the system menu]]
### [[7.5 Localization]]
### [[7.7 Accessibility]]
### [[7.8 Accelerometer]]

### [[7.10. crank]]

### [[7.11 Input handlers]]

### [Link to this](http://sdk.play.date/inside-playdate/\#M-autoLock "Link to this") 7.12. Device Auto Lock

Playdate will automatically lock if the user doesn’t press any buttons or use the crank for more than 3 minutes. In order for games that expect longer periods without interaction to continue to function, it is possible to manually disable the auto lock feature.

[Link to this](http://sdk.play.date/inside-playdate/#f-setAutoLockDisabled "Link to this")

playdate.setAutoLockDisabled(disable)

_True_ disables the 3 minute auto-lock feature. _False_ re-enables it and resets the timer back to 3 minutes.

|     |     |
| --- | --- |
| Note | Auto-lock will automatically be re-enabled when your game terminates. |

|     |     |
| --- | --- |
| Tip | If disabling auto-lock, developers should look for opportunities to re-enable auto-lock when appropriate. (For example, if your game is an MP3 audio player, auto-lock could be re-enabled when the user pauses the audio.) |

### [Link to this](http://sdk.play.date/inside-playdate/\#date-and-time "Link to this") 7.13. Date & Time

|     |     |
| --- | --- |
| Important | `playdate.getCurrentTimeMilliseconds()` and `playdate.getElapsedTime()` report game time, not real time. That is, when the game is not active — say, when the System Menu is visible, or when the Playdate is locked — that time is not counted by these functions. |

[Link to this](http://sdk.play.date/inside-playdate/#f-getCurrentTimeMilliseconds "Link to this")

playdate.getCurrentTimeMilliseconds()

Returns the number of milliseconds the game has been _active_ since launched.

[Link to this](http://sdk.play.date/inside-playdate/#f-resetElapsedTime "Link to this")

playdate.resetElapsedTime()

Resets the high-resolution timer.

[Link to this](http://sdk.play.date/inside-playdate/#f-getElapsedTime "Link to this")

playdate.getElapsedTime()

Returns the number of seconds since `playdate.resetElapsedTime()` was called. The value is a floating-point number with microsecond accuracy.

[Link to this](http://sdk.play.date/inside-playdate/#f-getSecondsSinceEpoch "Link to this")

playdate.getSecondsSinceEpoch()

Returns the number of seconds and milliseconds elapsed since midnight (hour 0), January 1 2000 UTC, as a list: _(seconds, milliseconds)_. This function is suitable for seeding the random number generator:

Sample code for seeding the random number generator

```
math.randomseed(playdate.getSecondsSinceEpoch())
```

[Link to this](http://sdk.play.date/inside-playdate/#f-getTime "Link to this")

playdate.getTime()

Returns a table with values for the local time, accessible via the following keys:

- _year_: 4-digit year (until 10,000 AD)

- _month_: month of the year, where 1 is January and 12 is December

- _day_: day of the month, 1 - 31

- _weekday_: day of the week, where 1 is Monday and 7 is Sunday

- _hour_: 0 - 23

- _minute_: 0 - 59

- _second_: 0 - 59 (or 60 on a leap second)

- _millisecond_: 0 - 999


[Link to this](http://sdk.play.date/inside-playdate/#f-epochFromTime "Link to this")

playdate.epochFromTime(time)

Returns the number of seconds and milliseconds between midnight (hour 0), January 1 2000 UTC and _time_, specified in local time, as a list: _(seconds, milliseconds)_.

_time_ should be a table of the same format as the one returned by [playdate.getTime()](http://sdk.play.date#f-getTime).

[Link to this](http://sdk.play.date/inside-playdate/#f-epochFromGMTTime "Link to this")

playdate.epochFromGMTTime(time)

Returns the number of seconds and milliseconds between midnight (hour 0), January 1 2000 UTC and _time_, specified in GMT time, as a list: _(seconds, milliseconds)_.

_time_ should be a table of the same format as the one returned by [playdate.getTime()](http://sdk.play.date#f-getTime).

[Link to this](http://sdk.play.date/inside-playdate/#f-getServerTime "Link to this")

playdate.getServerTime(function(time, error))

Queries the Playdate server for the current time, in seconds elapsed since midnight (hour 0), January 1 2000 UTC. This provides games with a reliable clock source, since the internal clock can be set by the user. The function is asynchronous, returning the server time to a callback function passed in. The callback function is given two arguments: the time (as a string, to avoid 32-bit rollover) if the query was successful, otherwise nil and an error string.

```
playdate.getServerTime(function(time, error)
    if time ~= nil then print("server time: "..time)
    else print("server error: "..error)
    end
end)
```

[Link to this](http://sdk.play.date/inside-playdate/#f-shouldDisplay24HourTime "Link to this")

playdate.shouldDisplay24HourTime()

Returns true if the user has set the 24-Hour Time preference in the Settings program.

### [Link to this](http://sdk.play.date/inside-playdate/\#M-debug "Link to this") 7.14. Debugging

Note that some [simulator-only functions](http://sdk.play.date#simulator) may also provide assistance in debugging.

[Link to this](http://sdk.play.date/inside-playdate/#f-print "Link to this")

print(string)

Text output from `print()` will be displayed in the simulator’s console, in black if generated by a game running in the simulator or in blue if it’s coming from a plugged-in Playdate device. Printed text is also copied to stdout, which is helpful if you run the simulator from the command line.

|     |     |
| --- | --- |
| Tip | You should ideally remove debugging print statements from your final games to improve performance. |

[Link to this](http://sdk.play.date/inside-playdate/#f-printTable "Link to this")

printTable(table)

Identical to `print()`, but instead of a string `printTable()` prints the contents of a table formatted for legibility.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/object_ to use `printTable`. |

|     |     |
| --- | --- |
| Tip | You should ideally remove debugging print statements from your final games to improve performance. |

[Link to this](http://sdk.play.date/inside-playdate/#v-argv "Link to this")

playdate.argv

The first item in the `playdate.argv` array is the filename of the currently running pdx. If the simulator is launched from the command line, any extra arguments passed there are added to this array; additionally, the [playdate.restart(arg)](http://sdk.play.date#f-restart) function puts its `arg` argument into the argv array, splitting the string on spaces outside of quoted ranges.

[Link to this](http://sdk.play.date/inside-playdate/#f-setNewlinePrinted "Link to this")

playdate.setNewlinePrinted(flag)

_flag_ determines whether or not the print() function adds a newline to the end of the printed text. Default is _true_.

[Link to this](http://sdk.play.date/inside-playdate/#f-drawFPS "Link to this")

playdate.drawFPS(x, y)

Calculates the current frames per second and draws that value at _x, y_.

[Link to this](http://sdk.play.date/inside-playdate/#f-getFPS "Link to this")

playdate.getFPS()

Returns the _measured, actual_ refresh rate in frames per second. This value may be different from the _specified_ refresh rate (see [playdate.display.getRefreshRate()](http://sdk.play.date#f-display.getRefreshRate)) by a little or a lot depending upon how much calculation is being done per frame.

[Link to this](http://sdk.play.date/inside-playdate/#f-where "Link to this")

where()

Returns a single-line stack trace as a string. For example:

```
main.lua:10 foo() < main.lua:18 (from C)
```

Use `print(where())` to see this trace written to the console.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/utilities/where_ to use this function. |

#### [Link to this](http://sdk.play.date/inside-playdate/\#_advanced_debugging "Link to this") Advanced Debugging

The Simulator supports the [Debug Adapter Protocol](https://microsoft.github.io/debug-adapter-protocol/) to do advanced debugging such as setting breakpoints, stepping code and inspecting variables in Lua. On the Mac we recommend using the [Nova extension](http://sdk.play.date#usingNova) for debugging. On Windows and Linux we recommend using the [Playdate Debug](https://github.com/midouest/vscode-playdate-debug) extension for Visual Studio Code.

### [Link to this](http://sdk.play.date/inside-playdate/\#M-profiling "Link to this") 7.15. Profiling

[Link to this](http://sdk.play.date/inside-playdate/#lua-sample "Link to this")

sample(name, function)

Suspect some code is running hot? Wrap it in an anonymous function and pass it to `sample()` like so:

```
sample("name of this sample", function()
        -- nested for loops, lots of table creation, member access...
end)
```

By moving around where you start and end the anonymous function in your code, you can get a better idea of where the problem lies.

Multiple code paths can be sampled at once by using different names for each sample.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/utilities/sampler_ to use this function. |

[Link to this](http://sdk.play.date/inside-playdate/#f-getStats "Link to this")

playdate.getStats()

Returns a table containing percentages of time spent in each system task over the last interval, if more than zero. Possible keys are

- `kernel`

- `serial`

- `game`

- `GC`

- `wifi`

- `audio`

- `trace`

- `idle`


|     |     |
| --- | --- |
| Important | `playdate.getStats()` only functions on a Playdate device. In the Simulator, this function returns `nil`. |

[Link to this](http://sdk.play.date/inside-playdate/#f-setStatsInterval "Link to this")

playdate.setStatsInterval(seconds)

`setStatsInterval()` sets the length of time for each sample frame of runtime stats. Set _seconds_ to zero to disable stats collection.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_using_the_simulator "Link to this") Using the Simulator

##### [Link to this](http://sdk.play.date/inside-playdate/\#_profiling_performance "Link to this") Profiling performance

1. Press the Sampler button.



![sampler button](http://sdk.play.date/Inside%20Playdate/sampler-button.png)

2. The Sampler window appears.



![sampling menu](http://sdk.play.date/Inside%20Playdate/sampling-menu.png)





Choose whether you want to sample:





- Simulator performance in Lua code

- Device performance in Lua code

- Device performance in C code


3. Press the `Sample` button in the upper right corner to start.


##### [Link to this](http://sdk.play.date/inside-playdate/\#_profiling_memory_usage "Link to this") Profiling memory usage

1. Press the Memory button.



![memory button](http://sdk.play.date/Inside%20Playdate/memory-button.png)

2. The Memory window appears:



![memory window](http://sdk.play.date/Inside%20Playdate/memory-window.png)





|     |     |
| --- | --- |
| Note | The first item displayed, `_G`, is the table where Lua stores global variables. |


##### [Link to this](http://sdk.play.date/inside-playdate/\#_profiling_malloc_calls_in_the_simulator "Link to this") Profiling malloc calls in the Simulator

1. From the Simulator menubar, choose **16MB** from the **Playdate** → **Malloc Pool** menu.

2. From the Simulator menubar, choose **Malloc Log** from the **Window** menu.

3. To make your life easier, click on the **Autorefresh** checkbox at the bottom of the window.



![malloc log](http://sdk.play.date/Inside%20Playdate/malloc-log.png)

4. There’s also a **Map** mode. See below.



![malloc log map](http://sdk.play.date/Inside%20Playdate/malloc-log-map.png)



Figure 5. _Gray_ denotes the total 16MB memory space; _white_ is the total amount of heap allocated so far; _purple_ — which overlaps the white region — is currently active or "in-use" memory.


##### [Link to this](http://sdk.play.date/inside-playdate/\#_profiling_malloc_calls_on_the_device "Link to this") Profiling malloc calls on the Device

1. From the Simulator menubar, choose the **Device Info** menu item.

2. In the Device Info window you can observe frames per second data, CPU usage data, and total memory usage.



![device info](http://sdk.play.date/Inside%20Playdate/device-info.png)





|     |     |
| --- | --- |
| Note | If large amounts of time spent in GC is reported it does not necessarily mean your game has a problem: if your game doesn’t use all of its allotted CPU, the Lua runtime will try and grab as much time as it can for GC, causing the GC percentage to balloon. See [Garbage Collection](http://sdk.play.date#M-garbage-collection) for details on how to modify the behavior of the garbage collector, including having it run for a shorter amount of time. |

3. Select "Memory" to see the memory map:



![device info map](http://sdk.play.date/Inside%20Playdate/device-info-map.png)


### [Link to this](http://sdk.play.date/inside-playdate/\#M-display "Link to this") 7.16. Display

The playdate.display module contains functions pertaining to Playdate’s screen. Functions related to drawing can be found in [playdate.graphics](http://sdk.play.date#M-graphics).

#### [Link to this](http://sdk.play.date/inside-playdate/\#_display_updating "Link to this") Display updating

[Link to this](http://sdk.play.date/inside-playdate/#f-display.setRefreshRate "Link to this")

playdate.display.setRefreshRate(rate)

Sets the desired refresh rate in frames per second. The default is 30 fps, which is a recommended figure that balances animation smoothness with performance and power considerations. Maximum is 50 fps.

If _rate_ is 0, [playdate.update()](http://sdk.play.date#c-update) is called as soon as possible. Since the display refreshes line-by-line, and unchanged lines aren’t sent to the display, the update cycle will be faster than 30 times a second but at an indeterminate rate. [playdate.getCurrentTimeMilliseconds()](http://sdk.play.date#f-getCurrentTimeMilliseconds) should then be used as a steady time base.

Equivalent to [`playdate->display->setRefreshRate()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-display.setRefreshRate) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-display.flush "Link to this")

playdate.display.flush()

Sends the contents of the frame buffer to the display immediately. Useful if you have called [playdate.stop()](http://sdk.play.date#f-stop) to disable update callbacks in, say, the case where your app updates the display only in reaction to button presses.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_other_display_properties "Link to this") Other display properties

[Link to this](http://sdk.play.date/inside-playdate/#f-display.getHeight "Link to this")

playdate.display.getHeight()

Returns the height the Playdate display, taking the current display scale into account; e.g., if the scale is 2, the values returned will be based off of a 200 x 120-pixel screen rather than the native 400 x 240. (See [playdate.display.setScale()](http://sdk.play.date#f-display.setScale).)

Equivalent to [`playdate->display->getHeight()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-display.getHeight) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-display.getWidth "Link to this")

playdate.display.getWidth()

Returns the width the Playdate display, taking the current display scale into account; e.g., if the scale is 2, the values returned will be based off of a 200 x 120-pixel screen rather than the native 400 x 240. (See [playdate.display.setScale()](http://sdk.play.date#f-display.setScale).)

Equivalent to [`playdate->display->getWidth()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-display.getWidth) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-display.getSize "Link to this")

playdate.display.getSize()

Returns the values _(width, height)_ describing the Playdate display size. Takes the current display scale into account; e.g., if the scale is 2, the values returned will be based off of a 200 x 120-pixel screen rather than the native 400 x 240. (See [playdate.display.setScale()](http://sdk.play.date#f-display.setScale).)

[Link to this](http://sdk.play.date/inside-playdate/#f-display.getRect "Link to this")

playdate.display.getRect()

Returns the values _(x, y, width, height)_ describing the Playdate display size. Takes the current display scale into account; e.g., if the scale is 2, the values returned will be based off of a 200 x 120-pixel screen rather than the native 400 x 240. (See [playdate.display.setScale()](http://sdk.play.date#f-display.setScale).)

[Link to this](http://sdk.play.date/inside-playdate/#f-display.setScale "Link to this")

playdate.display.setScale(scale)

Sets the display scale factor. Valid values for _scale_ are 1, 2, 4, and 8.

The top-left corner of the frame buffer is scaled up to fill the display; e.g., if the scale is set to 4, the pixels in rectangle \[0,100\] x \[0,60\] are drawn on the screen as 4 x 4 squares.

Equivalent to [`playdate->display->setScale()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-display.setScale) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-display.getScale "Link to this")

playdate.display.getScale()

Gets the display scale factor. Valid values for _scale_ are 1, 2, 4, and 8.

[Link to this](http://sdk.play.date/inside-playdate/#f-display.setInverted "Link to this")

playdate.display.setInverted(flag)

If the argument passed to `setInverted()` is true, the frame buffer will be drawn inverted (everything onscreen that was black will now be white, etc.)

Equivalent to [`playdate->display->setInverted()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-display.setInverted) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-display.getInverted "Link to this")

playdate.display.getInverted()

Returns the current value of the display invert flag.

[Link to this](http://sdk.play.date/inside-playdate/#f-display.setMosaic "Link to this")

playdate.display.setMosaic(x, y)

Adds a mosaic effect to the display. Valid _x_ and _y_ values are between 0 and 3, inclusive.

Equivalent to [`playdate->display->setMosaic()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-display.setMosaic) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-display.getMosaic "Link to this")

playdate.display.getMosaic()

Returns the current mosaic effect settings as multiple values ( _x_, _y_).

[Link to this](http://sdk.play.date/inside-playdate/#f-display.setOffset "Link to this")

playdate.display.setOffset(x, y)

Offsets the entire display by _x_, _y_. Offset values can be negative. The "exposed" part of the display is black or white, according to the value set in [playdate.graphics.setBackgroundColor()](http://sdk.play.date#f-graphics.setBackgroundColor). This is an efficient way to make a "shake" effect without redrawing anything.

|     |     |
| --- | --- |
| Caution | This function is different from [playdate.graphics.setDrawOffset()](http://sdk.play.date#f-graphics.setDrawOffset). |

Equivalent to [`playdate->display->setOffset()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-display.setOffset) in the C API.

Example: A screen shake effect using setOffset

```
-- You can copy and paste this example directly as your main.lua file to see it in action
import "CoreLibs/graphics"
import "CoreLibs/timer"

-- This function relies on the use of timers, so the timer core library
-- must be imported, and updateTimers() must be called in the update loop
local function screenShake(shakeTime, shakeMagnitude)
    -- Creating a value timer that goes from shakeMagnitude to 0, over
    -- the course of 'shakeTime' milliseconds
    local shakeTimer = playdate.timer.new(shakeTime, shakeMagnitude, 0)
    -- Every frame when the timer is active, we shake the screen
    shakeTimer.updateCallback = function(timer)
        -- Using the timer value, so the shaking magnitude
        -- gradually decreases over time
        local magnitude = math.floor(timer.value)
        local shakeX = math.random(-magnitude, magnitude)
        local shakeY = math.random(-magnitude, magnitude)
        playdate.display.setOffset(shakeX, shakeY)
    end
    -- Resetting the display offset at the end of the screen shake
    shakeTimer.timerEndedCallback = function()
        playdate.display.setOffset(0, 0)
    end
end

function playdate.update()
    playdate.timer.updateTimers()
    if playdate.buttonJustPressed(playdate.kButtonA) then
        -- Shake the screen for 500ms, with the screen
        -- shaking around by about 5 pixels on each side
        screenShake(500, 5)
    end

    -- A circle to be able to view what the shaking looks like
    playdate.graphics.fillCircleAtPoint(200, 120, 10)
end
```

[Link to this](http://sdk.play.date/inside-playdate/#f-display.getOffset "Link to this")

playdate.display.getOffset()

`getOffset()` returns the current display offset as multiple values ( _x_, _y_).

[Link to this](http://sdk.play.date/inside-playdate/#f-display.setFlipped "Link to this")

playdate.display.setFlipped(x, y)

Flips the display on the x or y axis, or both.

|     |     |
| --- | --- |
| Caution | Function arguments are booleans, and in Lua `0` evaluates to `true`. |

Equivalent to [`playdate->display->setFlipped()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-display.setFlipped) in the C API.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_displaying_an_image "Link to this") Displaying an image

[Link to this](http://sdk.play.date/inside-playdate/#f-display.loadImage "Link to this")

playdate.display.loadImage(path)

The simplest method for putting an image on the display. Copies the contents of the image at _path_ directly to the frame buffer. The image must be 400x240 pixels with no transparency.

|     |     |
| --- | --- |
| Tip | Loading an image via [playdate.graphics.image.new()](http://sdk.play.date#f-graphics.image.new-path) and drawing it at a desired coordinate with [playdate.graphics.image:draw()](http://sdk.play.date#m-graphics.imgDraw) offers more flexibility. |

### [Link to this](http://sdk.play.date/inside-playdate/\#M-easingFunctions "Link to this") 7.17. Easing functions

A set of easing functions to aid with animation timing.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/easing_ to use these functions. |

[Link to this](http://sdk.play.date/inside-playdate/#f-easingFunctions "Link to this")

playdate.easingFunctions.linear(t, b, c, d)

playdate.easingFunctions.inQuad(t, b, c, d)

playdate.easingFunctions.outQuad(t, b, c, d)

playdate.easingFunctions.inOutQuad(t, b, c, d)

playdate.easingFunctions.outInQuad(t, b, c, d)

playdate.easingFunctions.inCubic(t, b, c, d)

playdate.easingFunctions.outCubic(t, b, c, d)

playdate.easingFunctions.inOutCubic(t, b, c, d)

playdate.easingFunctions.outInCubic(t, b, c, d)

playdate.easingFunctions.inQuart(t, b, c, d)

playdate.easingFunctions.outQuart(t, b, c, d)

playdate.easingFunctions.inOutQuart(t, b, c, d)

playdate.easingFunctions.outInQuart(t, b, c, d)

playdate.easingFunctions.inQuint(t, b, c, d)

playdate.easingFunctions.outQuint(t, b, c, d)

playdate.easingFunctions.inOutQuint(t, b, c, d)

playdate.easingFunctions.outInQuint(t, b, c, d)

playdate.easingFunctions.inSine(t, b, c, d)

playdate.easingFunctions.outSine(t, b, c, d)

playdate.easingFunctions.inOutSine(t, b, c, d)

playdate.easingFunctions.outInSine(t, b, c, d)

playdate.easingFunctions.inExpo(t, b, c, d)

playdate.easingFunctions.outExpo(t, b, c, d)

playdate.easingFunctions.inOutExpo(t, b, c, d)

playdate.easingFunctions.outInExpo(t, b, c, d)

playdate.easingFunctions.inCirc(t, b, c, d)

playdate.easingFunctions.outCirc(t, b, c, d)

playdate.easingFunctions.inOutCirc(t, b, c, d)

playdate.easingFunctions.outInCirc(t, b, c, d)

playdate.easingFunctions.inElastic(t, b, c, d, \[a, p\])

playdate.easingFunctions.outElastic(t, b, c, d, \[a, p\])

playdate.easingFunctions.inOutElastic(t, b, c, d, \[a, p\])

playdate.easingFunctions.outInElastic(t, b, c, d, \[a, p\])

playdate.easingFunctions.inBack(t, b, c, d, \[s\])

playdate.easingFunctions.outBack(t, b, c, d, \[s\])

playdate.easingFunctions.inOutBack(t, b, c, d, \[s\])

playdate.easingFunctions.outInBack(t, b, c, d, \[s\])

playdate.easingFunctions.outBounce(t, b, c, d)

playdate.easingFunctions.inBounce(t, b, c, d)

playdate.easingFunctions.inOutBounce(t, b, c, d)

playdate.easingFunctions.outInBounce(t, b, c, d)

- _t_ is elapsed time

- _b_ is the beginning value

- _c_ is the change (or end value - start value)

- _d_ is the duration

- _a_ \- amplitude

- _p_ \- period parameter

- _s_ \- amount of "overshoot"


See [playdate.graphics.animator](http://sdk.play.date#C-graphics.animator), [playdate.timer](http://sdk.play.date#C-timer), or [playdate.frameTimer](http://sdk.play.date#C-frameTimer) for use-cases.

|     |     |
| --- | --- |
| Tip | [This page](https://easings.net/en) does a great job illustrating the shape of each easing function. (A mouseover will show an animation.) |

[[[7.18 Files]]]
### [Link to this](http://sdk.play.date/inside-playdate/\#M-geometry "Link to this") 7.19. Geometry

The playdate.geometry library allows you to store and manipulate points, sizes, rectangles, line segments, 2D vectors, polygons, and affine transforms.

All new geometry objects are created with a new() function using syntax like:

Example of creating a new rect

```
r = playdate.geometry.rect.new(x, y, width, height)
```

They can be output to the Simulator console:

Example of printing a rect to the console

```
print('rect', r)
```

And tested for equality:

Example of testing two rects for equality

```
b = r1 == r2
```

Fields on most geometry objects can be set directly:

Example of directly setting a rect’s x coordinate

```
r.x = 42.0
```

Functions for drawing playdate.geometry objects to screen are available in [playdate.graphics](http://sdk.play.date#M-graphics).

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-geometry.affineTransform "Link to this") Affine transform

Affine transforms can be used to modify the coordinates of points, rects (as axis aligned bounding boxes (AABBs)), line segments, and polygons. The underlying matrix is of the form:

The matrix of an affine transform

```
[m11 m12 tx]
[m21 m22 ty]
[ 0   0  1 ]
```

You can directly read and write the _m11_, _m12_, _m21_, _m22_, _tx_ and _ty_ values of an `affineTransform`.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.affineTransform.new "Link to this")

playdate.geometry.affineTransform.new(m11, m12, m21, m22, tx, ty)

Returns a new playdate.geometry.affineTransform. Use new() instead to get a new copy of the identity transform.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.affineTransform.new-1 "Link to this")

playdate.geometry.affineTransform.new()

Returns a new playdate.geometry.affineTransform that is the identity transform.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.copy "Link to this")

playdate.geometry.affineTransform:copy()

Returns a new copy of the affine transform.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.invert "Link to this")

playdate.geometry.affineTransform:invert()

Mutates the caller so that it is an affine transformation matrix constructed by inverting itself.

Inversion is generally used to provide reverse transformation of points within transformed objects. Given the coordinates (x, y), which have been transformed by a given matrix to new coordinates (x’, y’), transforming the coordinates (x’, y’) by the inverse matrix produces the original coordinates (x, y).

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.reset "Link to this")

playdate.geometry.affineTransform:reset()

Mutates the the caller, changing it to an identity transform matrix.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.concat "Link to this")

playdate.geometry.affineTransform:concat(af)

Mutates the the caller. The affine transform _af_ is concatenated to the caller.

Concatenation combines two affine transformation matrices by multiplying them together. You might perform several concatenations in order to create a single affine transform that contains the cumulative effects of several transformations.

Note that matrix operations are not commutative — the order in which you concatenate matrices is important. That is, the result of multiplying matrix t1 by matrix t2 does not necessarily equal the result of multiplying matrix t2 by matrix t1.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.translate "Link to this")

playdate.geometry.affineTransform:translate(dx, dy)

Mutates the caller by applying a translate transformation. x values are moved by _dx_, y values by _dy_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.translatedBy "Link to this")

playdate.geometry.affineTransform:translatedBy(dx, dy)

Returns a copy of the calling affine transform with a translate transformation appended.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.scale "Link to this")

playdate.geometry.affineTransform:scale(sx, \[sy\])

Mutates the caller by applying a scaling transformation.

If both parameters are passed, _sx_ is used to scale the x values of the transform, _sy_ is used to scale the y values.

If only one parameter is passed, it is used to scale both x and y values.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.scaledBy "Link to this")

playdate.geometry.affineTransform:scaledBy(sx, \[sy\])

Returns a copy of the calling affine transform with a scaling transformation appended.

If both parameters are passed, _sx_ is used to scale the x values of the transform, _sy_ is used to scale the y values.

If only one parameter is passed, it is used to scale both x and y values.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.rotate "Link to this")

playdate.geometry.affineTransform:rotate(angle, \[x, y\])

Mutates the caller by applying a rotation transformation.

_angle_ is the value, in degrees, by which to rotate the affine transform. A positive value specifies clockwise rotation and a negative value specifies counterclockwise rotation. If the optional _x_ and _y_ arguments are given, the transform rotates around ( _x_, _y_) instead of (0,0).

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform:rotate-point "Link to this")

playdate.geometry.affineTransform:rotate(angle, \[point\])

Mutates the caller by applying a rotation transformation.

_angle_ is the value, in degrees, by which to rotate the affine transform. A positive value specifies clockwise rotation and a negative value specifies counterclockwise rotation. If the optional [playdate.geometry.point](http://sdk.play.date#C-geometry.point) _point_ argument is given, the transform rotates around the _point_ instead of (0,0).

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.rotatedBy "Link to this")

playdate.geometry.affineTransform:rotatedBy(angle, \[x, y\])

Returns a copy of the calling affine transform with a rotate transformation appended.

_angle_ is the value, in degrees, by which to rotate the affine transform. A positive value specifies clockwise rotation and a negative value specifies counterclockwise rotation. If the optional _x_ and _y_ arguments are given, the transform rotates around ( _x_, _y_) instead of (0,0).

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform:rotatedBy-point "Link to this")

playdate.geometry.affineTransform:rotatedBy(angle, \[point\])

Returns a copy of the calling affine transform with a rotate transformation appended.

_angle_ is the value, in degrees, by which to rotate the affine transform. A positive value specifies clockwise rotation and a negative value specifies counterclockwise rotation. If the optional [point](http://sdk.play.date#C-geometry.point) _point_ argument is given, the transform rotates around the _point_ instead of (0,0).

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.skew "Link to this")

playdate.geometry.affineTransform:skew(sx, sy)

Mutates the caller, appending a skew transformation. _sx_ is the value by which to skew the x axis, and _sy_ the value for the y axis. Values are in degrees.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.skewedBy "Link to this")

playdate.geometry.affineTransform:skewedBy(sx, sy)

Returns the given transform with a skew transformation appended. _sx_ is the value by which to skew the x axis, and _sy_ the value for the y axis. Values are in degrees.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.transformedPoint "Link to this")

playdate.geometry.affineTransform:transformedPoint(p)

As above, but returns a new point rather than modifying _p_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.transformXY "Link to this")

playdate.geometry.affineTransform:transformXY(x, y)

Returns two values calculated by applying the affine transform to the point ( _x_, _y_)

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.affineTransform.mul_t "Link to this")

t1 \* t2

Returns the transform created by multiplying transform _t1_ by transform _t2_

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-geometry.arc "Link to this") Arc

playdate.geometry.arc implements an arc.

You can directly read or write the _x_, _y_, _radius_, _startAngle_, _endAngle_ and _clockwise_ values of an `arc`.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.arc.new "Link to this")

playdate.geometry.arc.new(x, y, radius, startAngle, endAngle, \[direction\])

Returns a new playdate.geometry.arc. Angles should be specified in degrees. Zero degrees represents the top of the circle.

![unitcircle](http://sdk.play.date/Inside%20Playdate/unitcircle.png)

If specified, _direction_ should be true for clockwise, false for counterclockwise. If not specified, the direction is inferred from the start and end angles.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.arc.copy "Link to this")

playdate.geometry.arc:copy()

Returns a new copy of the arc.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.arc.length "Link to this")

playdate.geometry.arc:length()

Returns the length of the arc.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.arc.isClockwise "Link to this")

playdate.geometry.arc:isClockwise()

Returns true if the direction of the arc is clockwise.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.arc.setIsClockwise "Link to this")

playdate.geometry.arc:setIsClockwise(flag)

Sets the direction of the arc.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.arc.pointOnArc "Link to this")

playdate.geometry.arc:pointOnArc(distance, \[extend\])

Returns a new [point](http://sdk.play.date#C-geometry.point) on the arc, `distance` pixels from the arc’s start angle. If `extend` is true, the returned point is allowed to project past the arc’s endpoints; otherwise, it is constrained to the arc’s initial point if `distance` is negative, or the end point if `distance` is greater than the arc’s length.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-geometry.lineSegment "Link to this") Line segment

playdate.geometry.lineSegment implements a line segment between two points in two-dimensional space.

You can directly read or write _x1_, _y1_, _x2_, or _y2_ values to a lineSegment.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.lineSegment.new "Link to this")

playdate.geometry.lineSegment.new(x1, y1, x2, y2)

Returns a new playdate.geometry.lineSegment.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.copy "Link to this")

playdate.geometry.lineSegment:copy()

Returns a new copy of the line segment.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.unpack "Link to this")

playdate.geometry.lineSegment:unpack()

Returns the values _x1, y1, x2, y2_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.length "Link to this")

playdate.geometry.lineSegment:length()

Returns the length of the line segment.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.offset "Link to this")

playdate.geometry.lineSegment:offset(dx, dy)

Modifies the line segment, offsetting its values by _dx_, _dy_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.offsetBy "Link to this")

playdate.geometry.lineSegment:offsetBy(dx, dy)

Returns a new line segment, the given segment offset by _dx_, _dy_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.midPoint "Link to this")

playdate.geometry.lineSegment:midPoint()

Returns a [playdate.geometry.point](http://sdk.play.date#C-geometry.point) representing the mid point of the line segment.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.pointOnLine "Link to this")

playdate.geometry.lineSegment:pointOnLine(distance, \[extend\])

Returns a [playdate.geometry.point](http://sdk.play.date#C-geometry.point) on the line segment, `distance` pixels from the start of the line. If `extend` is true, the returned point is allowed to project past the segment’s endpoints; otherwise, it is constrained to the line segment’s initial point if `distance` is negative, or the end point if `distance` is greater than the segment’s length.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.segmentVector "Link to this")

playdate.geometry.lineSegment:segmentVector()

Returns a [playdate.geometry.vector2D](http://sdk.play.date#C-geometry.vector2D) representation of the line segment.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.closestPointOnLineToPoint "Link to this")

playdate.geometry.lineSegment:closestPointOnLineToPoint(p)

Returns a [playdate.geometry.point](http://sdk.play.date#C-geometry.point) that is the closest point to point _p_ that is on the line segment.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.intersectsLineSegment "Link to this")

playdate.geometry.lineSegment:intersectsLineSegment(ls)

Returns true if there is an intersection between the caller and the line segment _ls_.

If there is an intersection, a [playdate.geometry.point](http://sdk.play.date#C-geometry.point) representing that point is also returned.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.fast_intersection "Link to this")

playdate.geometry.lineSegment.fast\_intersection(x1, y1, x2, y2, x3, y3, x4, y4)

For use in inner loops where speed is the priority.

Returns true if there is an intersection between the line segments defined by _(x1, y1)_, _(x2, y2)_ and _(x3, y3)_, _(x4, y4)_.
If there is an intersection, _x, y_ values representing the intersection point are also returned.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.intersectsPolygon "Link to this")

playdate.geometry.lineSegment:intersectsPolygon(poly)

Returns the values ( _intersects_, _intersectionPoints_).

_intersects_ is true if there is at least one intersection between the caller and [poly](http://sdk.play.date#C-geometry.polygon).

_intersectionPoints_ is an array of [playdate.geometry.point](http://sdk.play.date#C-geometry.point) s containing all intersection points between the caller and [poly](http://sdk.play.date#C-geometry.polygon).

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.lineSegment.intersectsRect "Link to this")

playdate.geometry.lineSegment:intersectsRect(rect)

Returns the values ( _intersects_, _intersectionPoints_).

_intersects_ is true if there is at least one intersection between the caller and [rect](http://sdk.play.date#C-geometry.rect).

_intersectionPoints_ is an array of [playdate.geometry.point](http://sdk.play.date#C-geometry.point) s containing all intersection points between the caller and [rect](http://sdk.play.date#C-geometry.rect).

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-geometry.point "Link to this") Point

playdate.geometry.point implements a two-dimensional point.
You can directly read or write the _x_ and _y_ values of a `point`.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.point.new "Link to this")

playdate.geometry.point.new(x, y)

Returns a new playdate.geometry.point.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.point.copy "Link to this")

playdate.geometry.point:copy()

Returns a new copy of the point.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.point.unpack "Link to this")

playdate.geometry.point:unpack()

Returns the values _x, y_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.point.offset "Link to this")

playdate.geometry.point:offset(dx, dy)

Modifies the point, offsetting its values by _dx_, _dy_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.point.offsetBy "Link to this")

playdate.geometry.point:offsetBy(dx, dy)

Returns a new point object, the given point offset by _dx_, _dy_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.point.squaredDistanceToPoint "Link to this")

playdate.geometry.point:squaredDistanceToPoint(p)

Returns the square of the distance to point _p_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.point.distanceToPoint "Link to this")

playdate.geometry.point:distanceToPoint(p)

Returns the distance to point _p_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.point.sub "Link to this")

p1 - p2

Returns the vector constructed by subtracting _p2_ from _p1_. By this construction, _p2_ \+ ( _p1_ \- _p2_) == _p1_.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-geometry.polygon "Link to this") Polygon

playdate.geometry.polygon implements two-dimensional open or closed polygons.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.polygon.new "Link to this")

playdate.geometry.polygon.new(x1, y1, x2, y2, ..., xn, yn)

playdate.geometry.polygon.new(p1, p2, ..., pn)

playdate.geometry.polygon.new(numberOfVertices)

`new(x1, y1, x2, y2, ..., xn, yn)` returns a new playdate.geometry.polygon with vertices _(x1, y1)_ through _(xn, yn)_. The Lua function `table.unpack()` can be used to turn an array into function arguments.

`new(p1, p2, ..., pn)` does the same, except the points are expressed via [point objects](http://sdk.play.date#C-geometry.point).

`new(numberOfVertices)` returns a new playdate.geometry.polygon with space allocated for _numberOfVertices_ vertices. All vertices are initially (0, 0). Vertex coordinates can be set with [playdate.geometry.polygon:setPointAt()](http://sdk.play.date#m-geometry.polygon.setPointAt).

|     |     |
| --- | --- |
| Tip | To draw a polygon, use [`playdate.graphics.drawPolygon()`](http://sdk.play.date#f-graphics.drawPolygon). |

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.copy "Link to this")

playdate.geometry.polygon:copy()

Returns a copy of a polygon.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.close "Link to this")

playdate.geometry.polygon:close()

`:close()` closes a polygon. If the polygon’s first and last point aren’t coincident, a line segment will be generated to connect them.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.isClosed "Link to this")

playdate.geometry.polygon:isClosed()

Returns true if the polygon is closed, false if not.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.containsPoint "Link to this")

playdate.geometry.polygon:containsPoint(p, \[fillRule\])

playdate.geometry.polygon:containsPoint(x, y, \[fillRule\])

Returns a boolean value, true if the [point](http://sdk.play.date#C-geometry.point) _p_ or the point at _(x, y)_ is contained within the caller polygon.

`fillrule` is an optional argument that can be one of the values defined in [playdate.graphics.setPolygonFillRule](http://sdk.play.date#f-graphics.setPolygonFillRule). By default `playdate.graphics.kPolygonFillEvenOdd` is used.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.getBounds "Link to this")

playdate.geometry.polygon:getBounds()

Returns multiple values ( _x_, _y_, _width_, _height_) giving the axis-aligned bounding box for the polygon.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.getBoundsRect "Link to this")

playdate.geometry.polygon:getBoundsRect()

Returns the axis-aligned bounding box for the given polygon as a [`playdate.geometry.rect`](http://sdk.play.date#C-geometry.rect) object.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.count "Link to this")

playdate.geometry.polygon:count()

Returns the number of points in the polygon.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.length "Link to this")

playdate.geometry.polygon:length()

Returns the total length of all line segments in the polygon.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.setPointAt "Link to this")

playdate.geometry.polygon:setPointAt(n, x, y)

Sets the polygon’s _n_-th point to ( _x_, _y_).

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.getPointAt "Link to this")

playdate.geometry.polygon:getPointAt(n)

Returns the polygon’s _n_-th point.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.intersects "Link to this")

playdate.geometry.polygon:intersects(p)

Returns true if the given polygon intersects the polygon _p_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.pointOnPolygon "Link to this")

playdate.geometry.polygon:pointOnPolygon(distance, \[extend\])

Returns a [playdate.geometry.point](http://sdk.play.date#C-geometry.point) on one of the polygon’s line segments, `distance` pixels from the start of the polygon. If `extend` is true, the point is allowed to project past the polygon’s ends; otherwise, it is constrained to the polygon’s initial point if `distance` is negative, or the last point if `distance` is greater than the polygon’s length.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.polygon.translate "Link to this")

playdate.geometry.polygon:translate(dx, dy)

Translates each point on the polygon by _dx_, _dy_ pixels.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-geometry.rect "Link to this") Rect

playdate.geometry.rect implements a rectangle.

You can directly read or write _x_, _y_, _width_, or _height_ values to a rect.

The values of _top_, _bottom_, _right_, _left_, _origin_, and _size_ are read-only.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.rect.new "Link to this")

playdate.geometry.rect.new(x, y, width, height)

Returns a new playdate.geometry.rect.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.copy "Link to this")

playdate.geometry.rect:copy()

Returns a new copy of the rect.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.toPolygon "Link to this")

playdate.geometry.rect:toPolygon()

Returns a new playdate.geometry.polygon version of the rect.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.unpack "Link to this")

playdate.geometry.rect:unpack()

Returns _x_, _y_, _width_ and _height_ as individual values.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.isEmpty "Link to this")

playdate.geometry.rect:isEmpty()

Returns true if a rectangle has zero width or height.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.isEqual "Link to this")

playdate.geometry.rect:isEqual(r2)

Returns true if the _x_, _y_, _width_, and _height_ values of the caller and _r2_ are all equal.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.intersects "Link to this")

playdate.geometry.rect:intersects(r2)

Returns true if _r2_ intersects the caller.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.intersection "Link to this")

playdate.geometry.rect:intersection(r2)

Returns a rect representing the overlapping portion of the caller and _r2_.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.rect.fast_intersection "Link to this")

playdate.geometry.rect.fast\_intersection(x1, y1, w1, h1, x2, y2, w2, h2)

For use in inner loops where speed is the priority. About 3x faster than [intersection](http://sdk.play.date#m-geometry.rect.intersection).

Returns multiple values ( _x, y, width, height_) representing the overlapping portion of the two rects defined by _x1, y1, w1, h1_ and _x2, y2, w2, h2_. If there is no intersection, (0, 0, 0, 0) is returned.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.union "Link to this")

playdate.geometry.rect:union(r2)

Returns the smallest possible rect that contains both the source rect and _r2_.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.rect.fast_union "Link to this")

playdate.geometry.rect.fast\_union(x1, y1, w1, h1, x2, y2, w2, h2)

For use in inner loops where speed is the priority. About 3x faster than [union](http://sdk.play.date#m-geometry.rect.union).

Returns multiple values ( _x, y, width, height_) representing the smallest possible rect that contains the two rects defined by _x1, y1, w1, h1_ and _x2, y2, w2, h2_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.inset "Link to this")

playdate.geometry.rect:inset(dx, dy)

Insets the rect by the given _dx_ and _dy_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.insetBy "Link to this")

playdate.geometry.rect:insetBy(dx, dy)

Returns a rect that is inset by the given _dx_ and _dy_, with the same center point.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.offset "Link to this")

playdate.geometry.rect:offset(dx, dy)

Offsets the rect by the given _dx_ and _dy_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.offsetBy "Link to this")

playdate.geometry.rect:offsetBy(dx, dy)

Returns a rect with its origin point offset by _dx_, _dy_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.rect.flipRelativeToRect "Link to this")

playdate.geometry.rect:flipRelativeToRect(r2, flip)

Flips the caller about the center of rect _r2_.

_flip_ should be one of the following constants:

- _playdate.geometry.kUnflipped_

- _playdate.geometry.kFlippedX_

- _playdate.geometry.kFlippedY_

- _playdate.geometry.kFlippedXY_


#### [Link to this](http://sdk.play.date/inside-playdate/\#C-geometry.size "Link to this") Size

You can directly read or write the _width_ and _height_ values of a `size`.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.size.new "Link to this")

playdate.geometry.size.new(width, height)

Returns a new playdate.geometry.size.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.size.copy "Link to this")

playdate.geometry.size:copy()

Returns a new copy of the size.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.size.unpack "Link to this")

playdate.geometry.size:unpack()

Returns the values _width, height_.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_utility_functions "Link to this") Utility functions

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.squaredDistanceToPoint "Link to this")

playdate.geometry.squaredDistanceToPoint(x1, y1, x2, y2)

Returns the square of the distance from point _(x1, y1)_ to point _(x2, y2)_.

Compared to [geometry.point:squaredDistanceToPoint()](http://sdk.play.date#m-geometry.point.squaredDistanceToPoint), this version will be slightly faster.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.distanceToPoint "Link to this")

playdate.geometry.distanceToPoint(x1, y1, x2, y2)

Returns the the distance from point _(x1, y1)_ to point _(x2, y2)_.

Compared to [geometry.point:distanceToPoint()](http://sdk.play.date#m-geometry.point.distanceToPoint), this version will be slightly faster.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-geometry.vector2D "Link to this") Vector

playdate.geometry.vector2D implements a two-dimensional vector.

You can directly read or write _dx_, or _dy_ values to a vector2D.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.vector2D.new "Link to this")

playdate.geometry.vector2D.new(x, y)

Returns a new playdate.geometry.vector2D.

[Link to this](http://sdk.play.date/inside-playdate/#f-geometry.vector2D.newPolar "Link to this")

playdate.geometry.vector2D.newPolar(length, angle)

Returns a new playdate.geometry.vector2D. Angles should be specified in degrees. Zero degrees represents the top of the circle.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.copy "Link to this")

playdate.geometry.vector2D:copy()

Returns a new copy of the vector2D.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.unpack "Link to this")

playdate.geometry.vector2D:unpack()

Returns the values _dx, dy_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.addVector "Link to this")

playdate.geometry.vector2D:addVector(v)

Modifies the caller by adding vector _v_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.scale "Link to this")

playdate.geometry.vector2D:scale(s)

Modifies the caller, scaling it by amount _s_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.scaledBy "Link to this")

playdate.geometry.vector2D:scaledBy(s)

Returns the given vector scaled by _s_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.normalize "Link to this")

playdate.geometry.vector2D:normalize()

Modifies the caller by normalizing it so that its length is 1. If the vector is (0,0), the vector is unchanged.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.normalized "Link to this")

playdate.geometry.vector2D:normalized()

Returns a new vector by normalizing the given vector.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.dotProduct "Link to this")

playdate.geometry.vector2D:dotProduct(v)

Returns the dot product of the caller and the vector _v_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.magnitude "Link to this")

playdate.geometry.vector2D:magnitude()

Returns the magnitude of the caller.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.magnitudeSquared "Link to this")

playdate.geometry.vector2D:magnitudeSquared()

Returns the square of the magnitude of the caller.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.projectAlong "Link to this")

playdate.geometry.vector2D:projectAlong(v)

Modifies the caller by projecting it along the vector _v_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.projectedAlong "Link to this")

playdate.geometry.vector2D:projectedAlong(v)

Returns a new vector created by projecting the given vector along the vector _v_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.angleBetween "Link to this")

playdate.geometry.vector2D:angleBetween(v)

Returns the angle between the caller and the vector _v_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.leftNormal "Link to this")

playdate.geometry.vector2D:leftNormal()

Returns a vector that is the left normal of the caller.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.rightNormal "Link to this")

playdate.geometry.vector2D:rightNormal()

Returns a vector that is the right normal of the caller.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.unm "Link to this")

-v

Returns the vector formed by negating the components of vector _v_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.add "Link to this")

v1 + v2

Returns the vector formed by adding vector _v2_ to vector _v1_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.sub "Link to this")

v1 - v2

Returns the vector formed by subtracting vector _v2_ from vector _v1_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.mul_s "Link to this")

v1 \* s

Returns the vector _v1_ scaled by _s_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.mul_v "Link to this")

v1 \* v2

Returns the dot product of the two vectors.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.mul_t "Link to this")

v1 \* t

Returns the vector transformed by transform _t_.

[Link to this](http://sdk.play.date/inside-playdate/#m-geometry.vector2D.div "Link to this")

v / s

Returns the vector divided by scalar _s_.

### [Link to this](http://sdk.play.date/inside-playdate/\#M-graphics "Link to this") 7.20. Graphics

The playdate.graphics module contains functions related to displaying information on the device screen.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_conventions "Link to this") Conventions

- The Playdate coordinate system has its origin point (0, 0) at the upper left. The x-axis increases to the right, and the y-axis increases downward.

- (0, 0) represents the upper-left corner of the first pixel onscreen. The center of that pixel is (0.5, 0.5).

- In the Playdate SDK, angle values should always be provided in degrees, and angle values returned will be in degrees. Not radians. (This is in contrast to Lua’s built-in math libraries, which use radians.)


#### [Link to this](http://sdk.play.date/inside-playdate/\#_contexts "Link to this") Contexts

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.pushContext "Link to this")

playdate.graphics.pushContext(\[image\])

Pushes the current graphics state to the context stack and creates a new context. If a [playdate.graphics.image](http://sdk.play.date#C-graphics.image) is given, drawing functions are applied to the image instead of the screen buffer.

|     |     |
| --- | --- |
| Important | If you draw into an image context with color set to _playdate.graphics.kColorClear_, those drawn pixels will be set to transparent. When you later draw the image into the framebuffer, those pixels will not be rendered, i.e., will act as transparent pixels in the image. |

|     |     |
| --- | --- |
| Note | [playdate.graphics.lockFocus( _image_)](http://sdk.play.date#f-graphics.lockFocus) will reroute drawing into an image, without saving the overall graphics context. |

Equivalent to [`playdate->graphics->pushContext()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.pushContext) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.popContext "Link to this")

playdate.graphics.popContext()

Pops a graphics context off the context stack and restores its state.

Equivalent to [`playdate->graphics->popContext()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.popContext) in the C API.

Example: Using contexts to reset drawing modifiers

```
local gfx = playdate.graphics

gfx.setLineWidth(1) -- Original line width
gfx.setColor(gfx.kColorBlack) -- Original color

gfx.pushContext() -- Creating a new graphics context
gfx.setLineWidth(5) -- Setting the line width to 5
gfx.setColor(gfx.kColorWhite) -- Setting the draw color to white
gfx.drawCircleAtPoint(200, 120, 10) -- Only thing you're trying to modify
gfx.popContext() -- All modifications done during the context get removed

-- Unaffected by modifiers and gets drawn with the original color/line width
gfx.drawLine(0, 120, 400, 120)
```

Example: Using contexts to draw something to an image

```
-- You can copy and paste this example directly as your main.lua file to see it in action
import "CoreLibs/graphics"

-- In this example, we'll be drawing a smiley face to an image, which saves our
-- drawing, makes it easier to draw, and helps improve performance since we don't
-- have to redraw each element separately each time
local gfx = playdate.graphics

local smileWidth, smileHeight = 36, 36
local smileImage = gfx.image.new(smileWidth, smileHeight)
-- Pushing our new image to the graphics context, so everything
-- drawn will be drawn directly to the image
gfx.pushContext(smileImage)
    -- => Indentation not required, but helps organize things!
    gfx.setColor(gfx.kColorWhite)
    -- Coordinates are based on the image being drawn into
    -- (e.g. (x=0, y=0) refers to the top left of the image)
    gfx.fillCircleInRect(0, 0, smileWidth, smileHeight)
    gfx.setColor(gfx.kColorBlack)
    -- Drawing the eyes
    gfx.fillCircleAtPoint(11, 13, 3)
    gfx.fillCircleAtPoint(25, 13, 3)
    -- Drawing the mouth
    gfx.setLineWidth(3)
    gfx.drawArc(smileWidth/2, smileHeight/2, 11, 115, 245)
    -- Drawing the outline
    gfx.setLineWidth(2)
    gfx.setStrokeLocation(gfx.kStrokeInside)
    gfx.drawCircleInRect(0, 0, smileWidth, smileHeight)
-- Popping context to stop drawing to image
gfx.popContext()

function playdate.update()
    -- Draw smile in the center of the screen
    local screenWidth, screenHeight = playdate.display.getSize()
    smileImage:drawAnchored(screenWidth/2, screenHeight/2, 0.5, 0.5)
end

-- Works really well with sprites! Just set the sprite image to your new image
local smileSprite = gfx.sprite.new(smileImage)
smileSprite:add()
```

#### [Link to this](http://sdk.play.date/inside-playdate/\#_clearing_the_screen "Link to this") Clearing the Screen

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.clear "Link to this")

playdate.graphics.clear(\[color\])

Clears the entire display, setting the color to either the given _color_ argument, or the current background color set in [setBackgroundColor(color)](http://sdk.play.date#f-graphics.setBackgroundColor) if no argument is given.

Equivalent to [`playdate->graphics->clear()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.clear) in the C API.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.image "Link to this") Image

PNG and GIF images in the source folder are compiled into a Playdate-specific format by **`pdc`**, and can be loaded into Lua with
[playdate.graphics.image.new(path)](http://sdk.play.date#f-graphics.image.new-path). Playdate images are 1 bit per pixel, with an optional alpha channel.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_image_basics "Link to this") Image basics

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.image.new "Link to this")

playdate.graphics.image.new(width, height, \[bgcolor\])

Creates a new blank image of the given width and height. The image can be drawn on using [playdate.graphics.pushContext()](http://sdk.play.date#f-graphics.pushContext) or [playdate.graphics.lockFocus()](http://sdk.play.date#f-graphics.lockFocus). The optional _bgcolor_ argument is one of the color constants as used in [playdate.graphics.setColor()](http://sdk.play.date#f-graphics.setColor), defaulting to _kColorClear_.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.image.new-path "Link to this")

playdate.graphics.image.new(path)

Returns a [playdate.graphics.image](http://sdk.play.date#C-graphics.image) object from the data at _path_. If there is no file at _path_, the function returns nil and a second value describing the error.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.load "Link to this")

playdate.graphics.image:load(path)

Loads a new image from the data at _path_ into an already-existing image, without allocating additional memory. The image at _path_ must be of the same dimensions as the original.

Returns _(success, \[error\])_. If the boolean _success_ is false, _error_ is also returned.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.copy "Link to this")

playdate.graphics.image:copy()

Returns a new `playdate.graphics.image` that is an exact copy of the original.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.getSize "Link to this")

playdate.graphics.image:getSize()

Returns the pair ( _width_, _height_)

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.image.imageSizeAtPath "Link to this")

playdate.graphics.imageSizeAtPath(path)

Returns the pair ( _width_, _height_) for the image at _path_ without actually loading the image.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.imgDraw "Link to this")

playdate.graphics.image:draw(x, y, \[flip, \[sourceRect\]\])

playdate.graphics.image:draw(p, \[flip, \[sourceRect\]\])

Draws the image with its upper-left corner at location ( _x_, _y_) or [playdate.geometry.point](http://sdk.play.date#C-geometry.point) _p_.

The optional _flip_ argument can be one of the following:

- _playdate.graphics.kImageUnflipped_: the image is drawn normally

- _playdate.graphics.kImageFlippedX_: the image is flipped left to right

- _playdate.graphics.kImageFlippedY_: the image is flipped top to bottom

- _playdate.graphics.kImageFlippedXY_: the image if flipped both ways; i.e., rotated 180 degrees


Alternately, one of the strings "flipX", "flipY", or "flipXY" can be used for the _flip_ argument.

_sourceRect_, if specified, will cause only the part of the image within sourceRect to be drawn. _sourceRect_ should be relative to the image’s bounds and can be a [playdate.geometry.rect](http://sdk.play.date#C-geometry.rect) or four integers, ( _x_, _y_, _w_, _h_), representing the rect.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.drawAnchored "Link to this")

playdate.graphics.image:drawAnchored(x, y, ax, ay, \[flip\])

Draws the image at location _(x, y)_ centered at the point within the image represented by _(ax, ay)_ in unit coordinate space. For example, values of _ax = 0.0_, _ay = 0.0_ represent the image’s top-left corner, _ax = 1.0_, _ay = 1.0_ represent the bottom-right, and _ax = 0.5_, _ay = 0.5_ represent the center of the image.

The _flip_ argument is optional; see [`playdate.graphics.image:draw()`](http://sdk.play.date#m-graphics.imgDraw) for valid values.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use this method. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.drawCentered "Link to this")

playdate.graphics.image:drawCentered(x, y, \[flip\])

Draws the image centered at location _(x, y)_.

The _flip_ argument is optional; see [`playdate.graphics.image:draw()`](http://sdk.play.date#m-graphics.imgDraw) for valid values.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use this method. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.clear "Link to this")

playdate.graphics.image:clear(color)

Erases the contents of the image, setting all pixels to white if _color_ is _playdate.graphics.kColorWhite_, black if it’s _playdate.graphics.kColorBlack_, or clear if it’s _playdate.graphics.kColorClear_. If the image is cleared to black or white, the mask (if it exists) is set to fully opaque. If the image is cleared to kColorClear and the image doesn’t have a mask, a mask is added to it.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.sample "Link to this")

playdate.graphics.image:sample(x, y)

Returns _playdate.graphics.kColorWhite_ if the image is white at ( _x_, _y_), _playdate.graphics.kColorBlack_ if it’s black, or _playdate.graphics.kColorClear_ if it’s transparent.

|     |     |
| --- | --- |
| Note | The upper-left pixel of the image is at coordinate _(0, 0)_. |

##### [Link to this](http://sdk.play.date/inside-playdate/\#_image_transformations "Link to this") Image transformations

|     |     |
| --- | --- |
| Important | The following functions can be quite slow, especially when rotating images off-axis. Transforming a large image can take many milliseconds on the device. Be sure to test performance on the hardware when using these functions. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.drawRotated "Link to this")

playdate.graphics.image:drawRotated(x, y, angle, \[scale, \[yscale\]\])

Draws this image centered at point _(x,y)_ at (clockwise) _angle_ degrees, scaled by optional argument _scale_, with an optional separate scaling for the y axis.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.rotatedImage "Link to this")

playdate.graphics.image:rotatedImage(angle, \[scale, \[yscale\]\])

Returns a new image containing this image rotated by (clockwise) _angle_ degrees, scaled by optional argument _scale_, with an optional separate scaling for the y axis.

|     |     |
| --- | --- |
| Caution | Unless rotating by a multiple of 180 degrees, the new image will have different dimensions than the original. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.drawScaled "Link to this")

playdate.graphics.image:drawScaled(x, y, scale, \[yscale\])

Draws this image with its upper-left corner at point _(x,y)_, scaled by amount _scale_, with an optional separate scaling for the y axis.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.scaledImage "Link to this")

playdate.graphics.image:scaledImage(scale, \[yscale\])

Returns a new image containing this image scaled by amount _scale_, with an optional separate scaling for the y axis.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.drawSampled "Link to this")

playdate.graphics.image:drawSampled(x, y, width, height, centerx, centery, dxx, dyx, dxy, dyy, dx, dy, z, tiltAngle, tile)

Draws the image as if it’s mapped onto a tilted plane, transforming the target coordinates to image coordinates using an affine transform:

```
x' = dxx * x + dyx * y + dx
y' = dxy * x + dyy * y + dy
```

- _x, y, width, height_: The rectangle to fill

- _centerx, centery_: The point in the above rectangle \[in (0,1)x(0,1) coordinates\] for the center of the transform

- _dxx, dyx, dxy, dyy, dx, dy_: Defines an affine transform from geometry coordinates to image coordinates

- _z_: The distance from the viewer to the target plane — lower z means more exaggerated perspective

- _tiltAngle_: The tilt of the target plane about the x axis, in degrees

- _tile_: A boolean, indicating whether the image is tiled on the target plane


The _Mode7Driver_ demo in the _/Examples_ folder of the SDK demonstrates the usage of this function.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_image_masks "Link to this") Image masks

Image masks are how transparency is handled by images on the Playdate. When an image is drawn, the image mask is checked to see what parts of the image should be transparent.

The image mask takes the form of another image that must be the same dimensions as the image that it is masking. Regions that should be transparent are filled in with black pixels and opaque regions are filled in with white pixels. Any transparent image that is created or loaded from a file will automatically have an image mask applied to it to handle the transparency. Fully opaque images will, by default, have no image mask. An image may only have at most one image mask.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.setMaskImage "Link to this")

playdate.graphics.image:setMaskImage(maskImage)

Sets the image’s mask to a copy of _maskImage_.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.getMaskImage "Link to this")

playdate.graphics.image:getMaskImage()

If the image has a mask, returns the mask as a separate image. Otherwise, returns `nil`.

|     |     |
| --- | --- |
| Important | The returned image references the original’s data, so drawing into this image alters the original image’s mask. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.addMask "Link to this")

playdate.graphics.image:addMask(\[opaque\])

Adds a mask to the image if it doesn’t already have one. If _opaque_ is `true` or not specified, the image mask applied will be completely white, so the image will be entirely opaque. If _opaque_ is `false`, the mask will be completely black, so the image will be entirely transparent.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.removeMask "Link to this")

playdate.graphics.image:removeMask()

Removes the mask from the image if it has one.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.hasMask "Link to this")

playdate.graphics.image:hasMask()

Returns _true_ if the image has a mask.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.clearMask "Link to this")

playdate.graphics.image:clearMask(\[opaque\])

Erases the contents of the image’s mask, so that the image is entirely opaque if _opaque_ is 1, transparent otherwise. This function has no effect if the image doesn’t have a mask.

Example: How transparency is handled by image masks

```
-- By default, new images are transparent, so an image mask is automatically applied to 'image'
local image = playdate.graphics.image.new(20, 20)
-- maskImage will be a 20x20 black image, to mark that the entire image should be transparent
local maskImage = image:getMaskImage()
maskImage:draw(0, 0)

-- When the image is drawn, there will be nothing drawn, because the image mask makes it all transparent
image:draw(0, 0)

-- Removing the mask here will result in 'image' no longer having transparency
image:removeMask()

-- Drawing the image again will draw a black square, because without an image mask, there is no transparency
image:draw(0, 0)

-- Hopefully this cements the concept that all transparency is handled by image masks
```

Example: Using image masks to apply a dither filter and a hole punch out effect

```
-- You can copy and paste this example directly as your main.lua file to see it in action
import "CoreLibs/graphics"

local gfx = playdate.graphics

-- Creating an image with a black circle
local circleDiameter = 25
local circleImage = gfx.image.new(circleDiameter, circleDiameter)
gfx.pushContext(circleImage)
    gfx.fillCircleInRect(0, 0, circleImage:getSize())
gfx.popContext()

-- Saving the original mask (the transparency in the corners of the image not covered by the circle)
local circleMask = circleImage:getMaskImage():copy()

-- Copying the original mask to preserve transparent regions around the circle
local ditherMask = circleMask:copy()
-- Drawing into mask with a dither effect
gfx.pushContext(ditherMask)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, ditherMask:getSize())
gfx.popContext()

-- Copying the original mask to preserve transparent regions around the circle
local holeMask = circleMask:copy()
-- Drawing a hole into mask
gfx.pushContext(holeMask)
    gfx.setColor(gfx.kColorBlack)
    local width, height = holeMask:getSize()
    gfx.fillCircleAtPoint(width/2, height/2, width/4)
gfx.popContext()

function playdate.update()
    -- Circle is drawn with dithered regions transparent
    circleImage:setMaskImage(ditherMask)
    circleImage:drawAnchored(100, 120, 0.5, 0.5)

    -- Circle is drawn with hole in center
    circleImage:setMaskImage(holeMask)
    circleImage:drawAnchored(200, 120, 0.5, 0.5)

    -- Resetting the original mask returns the circle to normal
    circleImage:setMaskImage(circleMask)
    circleImage:drawAnchored(300, 120, 0.5, 0.5)
end

-- Technical details: Why copy the mask after getting it? :getMaskImage() returns a reference
-- to the mask image. Using :setMaskImage after will update that mask image to a new image, which
-- overwrites the referenced image and the original is lost. That's why we make a copy. Of course,
-- no :copy() calls are necessary if you don't intend to save the original mask.
```

##### [Link to this](http://sdk.play.date/inside-playdate/\#_image_effects "Link to this") Image effects

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.drawTiled "Link to this")

playdate.graphics.image:drawTiled(x, y, width, height, \[flip\])

playdate.graphics.image:drawTiled(rect, \[flip\])

Tiles the image into the given rectangle, using either listed dimensions or a [`playdate.geometry.rect`](http://sdk.play.date#C-geometry.rect) object, and the optional flip style.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.drawBlurred "Link to this")

playdate.graphics.image:drawBlurred(x, y, radius, numPasses, ditherType, \[flip\], \[xPhase, yPhase\])

Draws a blurred version of the image at ( _x_, _y_).

- _radius_: A bigger radius means a more blurred result. Processing time is independent of the radius.

- _numPasses_: A box blur is used to blur the image. The more passes, the more closely the blur approximates a gaussian blur. However, higher values will take more time to process.

- _ditherType_: The algorithm to use when blurring the image, must be one of the values listed in [`playdate.graphics.image:blurredImage()`](http://sdk.play.date#m-graphics.image.blurredImage)

- _flip_: optional; see [`playdate.graphics.image:draw()`](http://sdk.play.date#m-graphics.imgDraw) for valid values.

- _xPhase_, _yPhase_: optional; integer values that affect the appearance of _playdate.graphics.image.kDitherTypeDiagonalLine_, _playdate.graphics.image.kDitherTypeVerticalLine_, _playdate.graphics.image.kDitherTypeHorizontalLine_, _playdate.graphics.image.kDitherTypeScreen_, _playdate.graphics.image.kDitherTypeBayer2x2_, _playdate.graphics.image.kDitherTypeBayer4x4_, and _playdate.graphics.image.kDitherTypeBayer8x8_.


[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.blurredImage "Link to this")

playdate.graphics.image:blurredImage(radius, numPasses, ditherType, \[padEdges, \[xPhase, yPhase\]\])

Returns a blurred copy of the caller.

- _radius_: A bigger radius means a more blurred result. Processing time is independent of the radius.

- _numPasses_: A box blur is used to blur the image. The more passes, the more closely the blur approximates a gaussian blur. However, higher values will take more time to process.

- _ditherType_: The original image is blurred into a greyscale image then dithered back to 1-bit using one of the following dithering algorithms:



- _playdate.graphics.image.kDitherTypeNone_

- _playdate.graphics.image.kDitherTypeDiagonalLine_

- _playdate.graphics.image.kDitherTypeVerticalLine_

- _playdate.graphics.image.kDitherTypeHorizontalLine_

- _playdate.graphics.image.kDitherTypeScreen_

- _playdate.graphics.image.kDitherTypeBayer2x2_

- _playdate.graphics.image.kDitherTypeBayer4x4_

- _playdate.graphics.image.kDitherTypeBayer8x8_

- _playdate.graphics.image.kDitherTypeFloydSteinberg_

- _playdate.graphics.image.kDitherTypeBurkes_

- _playdate.graphics.image.kDitherTypeAtkinson_


- _padEdges_: Boolean indicating whether the edges of the images should be padded to accommodate the blur radius. Defaults to false.

- _xPhase_, _yPhase_: optional; integer values that affect the appearance of _playdate.graphics.image.kDitherTypeDiagonalLine_, _playdate.graphics.image.kDitherTypeVerticalLine_, _playdate.graphics.image.kDitherTypeHorizontalLine_, _playdate.graphics.image.kDitherTypeScreen_, _playdate.graphics.image.kDitherTypeBayer2x2_, _playdate.graphics.image.kDitherTypeBayer4x4_, and _playdate.graphics.image.kDitherTypeBayer8x8_.


[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.drawFaded "Link to this")

playdate.graphics.image:drawFaded(x, y, alpha, ditherType)

Draws a partially transparent image with its upper-left corner at location ( _x_, _y_)

- _alpha_: The alpha value used to draw the image, with 1 being fully opaque, and 0 being completely transparent.

- _ditherType_: The caller is faded using one of the dithering algorithms listed in [`playdate.graphics.image:blurredImage()`](http://sdk.play.date#m-graphics.image.blurredImage)


[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.fadedImage "Link to this")

playdate.graphics.image:fadedImage(alpha, ditherType)

Returns a faded version of the caller.

- _alpha_: The alpha value assigned to the caller, in the range 0.0 - 1.0. If an image mask already exists it is multiplied by _alpha_.

- _ditherType_: The caller is faded into a greyscale image and dithered with one of the dithering algorithms listed in [playdate.graphics.image:blurredImage()](http://sdk.play.date#m-graphics.image.blurredImage)


[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.setInverted "Link to this")

playdate.graphics.image:setInverted(flag)

If _flag_ is true, the image will be drawn with its colors inverted. If the image is being used as a stencil, its behavior is reversed: pixels are drawn where the stencil is black, nothing is drawn where the stencil is white.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.invertedImage "Link to this")

playdate.graphics.image:invertedImage()

Returns a color-inverted copy of the caller.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.blendWithImage "Link to this")

playdate.graphics.image:blendWithImage(image, alpha, ditherType)

Returns an image that is a blend between the caller and _image_.

- _image_: the playdate.graphics.image to be blended with the caller.

- _alpha_: The alpha value assigned to the caller. _image_ will have an alpha of (1 - _alpha_).

- _ditherType_: The caller and _image_ are blended into a greyscale image and dithered with one of the dithering algorithms listed in [`playdate.graphics.image:blurredImage()`](http://sdk.play.date#m-graphics.image.blurredImage)


[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.image.vcrPauseFilterImage "Link to this")

playdate.graphics.image:vcrPauseFilterImage()

Returns an image created by applying a VCR pause effect to the calling image.

To add a VCR effect to a single image, call this function once on the source image; the function will return a distorted version of the source image. To add a VCR effect to a series of frames / video, call this function on every frame and display each returned image. (This function uses an internal random number to determine the appearance of the effect on each frame, so the effect will vary from frame to frame in a way that makes it appear like "live" paused video.)

##### [Link to this](http://sdk.play.date/inside-playdate/\#_other_image_stuff "Link to this") Other image stuff

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.checkAlphaCollision "Link to this")

playdate.graphics.checkAlphaCollision(image1, x1, y1, flip1, image2, x2, y2, flip2)

Returns true if the non-alpha-masked portions of _image1_ and _image2_ overlap if they were drawn at positions ( _x1_, _y1_) and ( _x2_, _y2_) and flipped according to _flip1_ and _flip2_, which should each be one of the values listed in [`playdate.graphics.image:draw()`](http://sdk.play.date#m-graphics.imgDraw).

#### [Link to this](http://sdk.play.date/inside-playdate/\#_color_pattern "Link to this") Color & Pattern

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setColor "Link to this")

playdate.graphics.setColor(color)

Sets and gets the current drawing color for primitives.

_color_ should be one of the constants:

- _playdate.graphics.kColorBlack_

- _playdate.graphics.kColorWhite_

- _playdate.graphics.kColorClear_

- _playdate.graphics.kColorXOR_


This color applies to drawing primitive shapes such as lines and rectangles, not bitmap images.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getColor "Link to this")

playdate.graphics.getColor()

Gets the current drawing color for primitives.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setBackgroundColor "Link to this")

playdate.graphics.setBackgroundColor(color)

Sets the color used for drawing the background, if necessary, before [playdate.graphics.sprite](http://sdk.play.date#C-graphics.sprite) s are drawn on top.

_color_ should be one of the constants:

- _playdate.graphics.kColorBlack_

- _playdate.graphics.kColorWhite_

- _playdate.graphics.kColorClear_


Use _kColorClear_ if you intend to draw behind sprites.

Equivalent to [`playdate->graphics->setBackgroundColor()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setBackgroundColor) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getBackgroundColor "Link to this")

playdate.graphics.getBackgroundColor()

Gets the color used for drawing the background, if necessary, before [playdate.graphics.sprite](http://sdk.play.date#C-graphics.sprite) s are drawn on top.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setPattern "Link to this")

playdate.graphics.setPattern(pattern)

Sets the 8x8 pattern used for drawing. The _pattern_ argument is an array of 8 numbers describing the bitmap for each row; for example, _{ 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55 }_ specifies a checkerboard pattern. An additional 8 numbers can be specified for an alpha mask bitmap.

`playdate.graphics.setPattern(image, [x, y])`

Uses the given [playdate.graphics.image](http://sdk.play.date#C-graphics.image) to set the 8 x 8 pattern used for drawing. The optional _x_, _y_ offset (default 0, 0) indicates the top left corner of the 8 x 8 pattern.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setDitherPattern "Link to this")

playdate.graphics.setDitherPattern(alpha, \[ditherType\])

Sets the pattern used for drawing to a dithered pattern. If the current drawing color is white, the pattern is white pixels on a transparent background and (due to a bug) the _alpha_ value is inverted: 1.0 is transparent and 0 is opaque. Otherwise, the pattern is black pixels on a transparent background and _alpha_ 0 is transparent while 1.0 is opaque.

The optional _ditherType_ argument is a dither type as used in [`playdate.graphics.image:blurredImage()`](http://sdk.play.date#m-graphics.image.blurredImage), and should be an ordered dither type; i.e., line, screen, or Bayer.

|     |     |
| --- | --- |
| Caution | The error-diffusing dither types Floyd-Steinberg ( `kDitherTypeFloydSteinberg`), Burkes ( `kDitherTypeBurkes`), and Atkinson ( `kDitherTypeAtkinson`) are allowed but produce very unpredictable results here. |

#### [Link to this](http://sdk.play.date/inside-playdate/\#_drawing "Link to this") Drawing

##### [Link to this](http://sdk.play.date/inside-playdate/\#_line "Link to this") Line

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawLine "Link to this")

playdate.graphics.drawLine(x1, y1, x2, y2)

playdate.graphics.drawLine(ls)

Draws a line from ( _x1_, _y1_) to ( _x2_, _y2_), or draws the [playdate.geometry.lineSegment](http://sdk.play.date#C-geometry.lineSegment) _ls_.

Equivalent to [`playdate->graphics->drawLine()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.drawLine) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setLineCapStyle "Link to this")

playdate.graphics.setLineCapStyle(style)

Specifies the shape of the endpoints drawn by [drawLine](http://sdk.play.date#f-graphics.drawLine).

_style_ should be one of these constants:

- _playdate.graphics.kLineCapStyleButt_

- _playdate.graphics.kLineCapStyleRound_

- _playdate.graphics.kLineCapStyleSquare_


Equivalent to [`playdate->graphics->setLineCapStyle()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setLineCapStyle) in the C API.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_pixel "Link to this") Pixel

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawPixel "Link to this")

playdate.graphics.drawPixel(x, y)

Draw a single pixel in the current color at ( _x_, _y_).

`playdate.graphics.drawPixel(p)`

Draw a single pixel in the current color at [playdate.geometry.point](http://sdk.play.date#C-geometry.point) _p_.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_rect "Link to this") Rect

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawRect "Link to this")

playdate.graphics.drawRect(x, y, w, h)

playdate.graphics.drawRect(r)

Draws the rect _r_ or the rect with origin ( _x_, _y_) with a size of ( _w_, _h_).

Equivalent to [`playdate->graphics->drawRect()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.drawRect) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.fillRect "Link to this")

playdate.graphics.fillRect(x, y, width, height)

playdate.graphics.fillRect(r)

Draws the filled rectangle _r_ or the rect at ( _x_, _y_) of the given width and height.

Equivalent to [`playdate->graphics->fillRect()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.fillRect) in the C API.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_round_rect "Link to this") Round rect

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawRoundRect "Link to this")

playdate.graphics.drawRoundRect(x, y, w, h, radius)

playdate.graphics.drawRoundRect(r, radius)

Draws a rectangle with rounded corners in the rect _r_ or the rect with origin ( _x_, _y_) and size ( _w_, _h_).

_radius_ defines the radius of the corners.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.fillRoundRect "Link to this")

playdate.graphics.fillRoundRect(x, y, w, h, radius)

playdate.graphics.fillRoundRect(r, radius)

Draws a filled rectangle with rounded corners in the rect _r_ or the rect with origin ( _x_, _y_) and size ( _w_, _h_).

_radius_ defines the radius of the corners.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_arc "Link to this") Arc

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use the arc drawing functions. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawArc "Link to this")

playdate.graphics.drawArc(arc)

playdate.graphics.drawArc(x, y, radius, startAngle, endAngle)

Draws an arc using the current color.

Angles are specified in degrees, not radians.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_circle "Link to this") Circle

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use the circle drawing functions. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawCircleAtPoint "Link to this")

playdate.graphics.drawCircleAtPoint(x, y, radius)

playdate.graphics.drawCircleAtPoint(p, radius)

Draws a circle at the point _(x, y)_ (or _p_) with radius _radius_.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawCircleInRect "Link to this")

playdate.graphics.drawCircleInRect(x, y, width, height)

playdate.graphics.drawCircleInRect(r)

Draws a circle in the rect _r_ or the rect with origin _(x, y)_ and size _(width, height)_.

If the rect is not a square, the circle will be drawn centered in the rect.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.fillCircleAtPoint "Link to this")

playdate.graphics.fillCircleAtPoint(x, y, radius)

playdate.graphics.fillCircleAtPoint(p, radius)

Draws a filled circle at the point _(x, y)_ (or _p_) with radius _radius_.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.fillCircleInRect "Link to this")

playdate.graphics.fillCircleInRect(x, y, width, height)

playdate.graphics.fillCircleInRect(r)

Draws a filled circle in the rect _r_ or the rect with origin _(x, y)_ and size _(width, height)_.

If the rect is not a square, the circle will be drawn centered in the rect.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_ellipse "Link to this") Ellipse

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawEllipseInRect "Link to this")

playdate.graphics.drawEllipseInRect(x, y, width, height, \[startAngle, endAngle\])

playdate.graphics.drawEllipseInRect(rect, \[startAngle, endAngle\])

Draws an ellipse in the rect _r_ or the rect with origin _(x, y)_ and size _(width, height)_.

_startAngle_ and _endAngle_, if provided, should be in degrees (not radians), and will cause only the segment of the ellipse between _startAngle_ and _endAngle_ to be drawn.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.fillEllipseInRect "Link to this")

playdate.graphics.fillEllipseInRect(x, y, width, height, \[startAngle, endAngle\])

playdate.graphics.fillEllipseInRect(rect, \[startAngle, endAngle\])

Draws a filled ellipse in the rect _r_ or the rect with origin _(x, y)_ and size _(width, height)_.

_startAngle_ and _endAngle_, if provided, should be in degrees (not radians), and will cause only the segment of the ellipse between _startAngle_ and _endAngle_ to be drawn.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_polygon "Link to this") Polygon

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawPolygon "Link to this")

playdate.graphics.drawPolygon(p)

Draw the [playdate.geometry.polygon](http://sdk.play.date#C-geometry.polygon) _p_. Only draws a line between the first and last vertex if the polygon is [closed](http://sdk.play.date#m-geometry.polygon.close).

Line width is specified by [setLineWidth()](http://sdk.play.date#f-graphics.setLineWidth).

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawPolygon-list "Link to this")

playdate.graphics.drawPolygon(x1, y1, x2, y2, \[...\])

Draw the polygon specified by the given sequence of x,y coordinates, including an edge between the last vertex and the first. The Lua function `table.unpack()` can be used to turn an array into function arguments.

Line width is specified by [setLineWidth()](http://sdk.play.date#f-graphics.setLineWidth).

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.fillPolygon "Link to this")

playdate.graphics.fillPolygon(x1, y1, x2, y2, \[...\])

Fills the polygon specified by a list of x,y coordinates. An edge between the last vertex and the first is assumed.

Equivalent to [`playdate->graphics->fillPolygon()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.fillPolygon) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.fillPolygon-p "Link to this")

playdate.graphics.fillPolygon(p)

Fills the polygon specified by the [playdate.geometry.polygon](http://sdk.play.date#C-geometry.polygon) _p_ with the currently selected color or pattern. The function throws an error if the polygon is not [closed](http://sdk.play.date#m-geometry.polygon.isClosed).

|     |     |
| --- | --- |
| Tip | The Lua function `table.unpack()` can be used to turn an array into function arguments. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setPolygonFillRule "Link to this")

playdate.graphics.setPolygonFillRule(rule)

Sets the winding rule for filling polygons, one of:

- _playdate.graphics.kPolygonFillNonZero_

- _playdate.graphics.kPolygonFillEvenOdd_


See [https://en.wikipedia.org/wiki/Nonzero-rule](https://en.wikipedia.org/wiki/Nonzero-rule) for an explanation of the winding rule.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_triangle "Link to this") Triangle

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawTriangle "Link to this")

playdate.graphics.drawTriangle(x1, y1, x2, y2, x3, y3)

Draws a triangle with vertices ( _x1_, _y1_), ( _x2_, _y2_), and ( _x3_, _y3_).

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.fillTriangle "Link to this")

playdate.graphics.fillTriangle(x1, y1, x2, y2, x3, y3)

Draws a filled triangle with vertices ( _x1_, _y1_), ( _x2_, _y2_), and ( _x3_, _y3_).

Equivalent to [`playdate->graphics->fillTriangle()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.fillTriangle) in the C API.

##### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.nineSlice "Link to this") Nine slice

A "9 slice" is a rectangular image that is made "stretchable" by being sliced into nine pieces — the four corners, the four edges, and the center.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/nineslice_ to use these functions. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.nineSlice.new "Link to this")

playdate.graphics.nineSlice.new(imagePath, innerX, innerY, innerWidth, innerHeight)

Returns a new 9 slice image from the image at imagePath with the stretchable region defined by other parameters. The arguments represent the origin and dimensions of the innermost ("center") slice.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.nineSlice.getSize "Link to this")

playdate.graphics.nineSlice:getSize()

Returns the size of the 9 slice image as a pair _(width, height)_.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.nineSlice.getMinSize "Link to this")

playdate.graphics.nineSlice:getMinSize()

Returns the minimum size of the 9 slice image as a pair _(width, height)_.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.nineSlice.drawInRect "Link to this")

playdate.graphics.nineSlice:drawInRect(x, y, width, height)

playdate.graphics.nineSlice:drawInRect(rect)

Draws the 9 slice image at the desired coordinates by stretching the defined region to achieve the width and height inputs.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_perlin_noise "Link to this") Perlin noise

Perlin noise is an algorithm useful for generating "organic" looking things procedurally, such as terrain, visual effects, and more. For a good introduction to Perlin noise, see: [http://flafla2.github.io/2014/08/09/perlinnoise.html](http://flafla2.github.io/2014/08/09/perlinnoise.html)

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.perlin "Link to this")

playdate.graphics.perlin(x, y, z, repeat, \[octaves, persistence\])

Returns the Perlin value (from 0.0 to 1.0) at position _(x, y, z)_.

If _repeat_ is greater than 0, the pattern of noise will repeat at that point on all 3 axes.

_octaves_ is the number of octaves of noise to apply. Compute time increases linearly with each additional octave, but the results are a bit more organic, consisting of a combination of larger and smaller variations.

When using more than one octave, _persistence_ is a value from 0.0 - 1.0 describing the amount the amplitude is scaled each octave. The lower the value of _persistence_, the less influence each successive octave has on the final value.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.perlinArray "Link to this")

playdate.graphics.perlinArray(count, x, dx, \[y, dy, z, dz, repeat, octaves, persistence\])

Returns an array of Perlin values at once, avoiding the performance penalty of calling _perlin()_ multiple times in a loop.

The parameters are the same as _perlin()_ except:

_count_ is the number of values to be returned.

_dx_, _dy_, and _dz_ are how far to step along the x, y, and z axes in each iteration.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_qrcode "Link to this") QRCode

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.generateQRCode "Link to this")

playdate.graphics.generateQRCode(stringToEncode, desiredEdgeDimension, callback)

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/qrcode_ to use this function. |

|     |     |
| --- | --- |
| Caution | This function uses [`playdate.timer`](http://sdk.play.date#C-timer) internally, so be sure to call [`playdate.timer.updateTimers()`](http://sdk.play.date#f-timer.updateTimers) in your main [`playdate.update()`](http://sdk.play.date#c-update) function, otherwise the callback will never be invoked. |

Asynchronously returns an image representing a QR code for the passed-in string to the function `callback`. The arguments passed to the callback are [_image_](http://sdk.play.date#C-graphics.image), _errorMessage_. (If an _errorMessage_ string is returned, _image_ will be nil.)

`desiredEdgeDimension` lets you specify an approximate edge dimension in pixels for the desired QR code, though the function has limited flexibility in sizing QR codes, based on the amount of information to be encoded, and the restrictions of a 1-bit screen. The function will attempt to generate a QR code _smaller_ than `desiredEdgeDimension` if possible. (Note that QR codes always have the same width and height.)

If you specify nil for `desiredEdgeDimension`, the returned image will balance small size with easy readability. If you specify 0, the returned image will be the smallest possible QR code for the specified string.

`generateQRCode()` will return a reference to the [timer](http://sdk.play.date#C-timer) it uses to run asynchronously. If you wish to stop execution of the background process generating the QR code, call [`:remove()`](http://sdk.play.date#m-timer.remove) on that returned timer.

|     |     |
| --- | --- |
| Tip | If you know ahead of time what data you plan to encode, it is much faster to pre-generate the QR code, store it as a .png file in your game, and draw the .png at runtime. You can use [`playdate.simulator.writeToFile()`](http://sdk.play.date#f-simulator.writeToFile) to create this .png file. |

##### [Link to this](http://sdk.play.date/inside-playdate/\#_sine_wave "Link to this") Sine wave

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawSineWave "Link to this")

playdate.graphics.drawSineWave(startX, startY, endX, endY, startAmplitude, endAmplitude, period, \[phaseShift\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use this function. |

Draws an approximation of a sine wave between the points _startX, startY_ and _endX, endY_.

- _startAmplitude_: The number of pixels above and below the line from _startX, startY_ and _endX, endY_ the peaks and valleys of the wave will be drawn at the start of the wave.

- _endAmplitude_: The number of pixels above and below the line from _startX, startY_ and _endX, endY_ the peaks and valleys of the wave will be drawn at the end of the wave.

- _period_: The distance between peaks, in pixels.

- _phaseShift_: If provided, specifies the wave’s offset, in pixels.


#### [Link to this](http://sdk.play.date/inside-playdate/\#_drawing_modifiers "Link to this") Drawing Modifiers

##### [Link to this](http://sdk.play.date/inside-playdate/\#_clipping "Link to this") Clipping

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setClipRect "Link to this")

playdate.graphics.setClipRect(x, y, width, height)

playdate.graphics.setClipRect(rect)

`setClipRect()` sets the clipping rectangle for all subsequent graphics drawing, including bitmaps. The argument can either be separate dimensions or a [playdate.geometry.rect](http://sdk.play.date#C-geometry.rect) object. The clip rect is automatically cleared at the beginning of the [`playdate.update()`](http://sdk.play.date#c-update) callback. The function uses world coordinates; that is, the given rectangle will be translated by the current drawing offset. To use screen coordinates instead, use [`setScreenClipRect()`](http://sdk.play.date#f-graphics.setScreenClipRect)

Equivalent to [`playdate->graphics->setClipRect()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setClipRect) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setClipRect-rect "Link to this")

playdate.graphics.setClipRect(rect)

`setClipRect()` sets the clipping rectangle for all subsequent graphics drawing, including bitmaps. The argument can either be separate dimensions or a [playdate.geometry.rect](http://sdk.play.date#C-geometry.rect) object. The clip rect is automatically cleared at the beginning of the [`playdate.update()`](http://sdk.play.date#c-update) callback. The function uses world coordinates; that is, the given rectangle will be translated by the current drawing offset. To use screen coordinates instead, use [`setScreenClipRect()`](http://sdk.play.date#f-graphics.setScreenClipRect)

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getClipRect "Link to this")

playdate.graphics.getClipRect()

`getClipRect()` returns multiple values ( _x_, _y_, _width_, _height_) giving the current clipping rectangle.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setScreenClipRect "Link to this")

playdate.graphics.setScreenClipRect(x, y, width, height)

playdate.graphics.setScreenClipRect(rect)

Sets the clip rectangle as above, but uses screen coordinates instead of world coordinates—​that is, it ignores the current drawing offset.

Equivalent to [`playdate->graphics->setScreenClipRect()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setScreenClipRect) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getScreenClipRect "Link to this")

playdate.graphics.getScreenClipRect()

Returns the clip rect as in `getClipRect()`, but using screen coordinates instead of world coordinates.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.clearClipRect "Link to this")

playdate.graphics.clearClipRect()

Clears the current clipping rectangle, set with [`setClipRect()`](http://sdk.play.date#f-graphics.setClipRect).

Equivalent to [`playdate->graphics->clearClipRect()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.clearClipRect) in the C API.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_stencil "Link to this") Stencil

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setStencilImage "Link to this")

playdate.graphics.setStencilImage(image, \[tile\])

Sets the current [stencil](https://en.wikipedia.org/wiki/Stencil_buffer) to the given image. While the stencil is active, drawing functions will only draw pixels where the stencil is white and nothing is drawn where the stencil is black. If _tile_ is set, the the stencil will be tiled; in this case, the image width must be a multiple of 32 pixels.

Equivalent to [`playdate->graphics->setStencilImage()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setStencilImage) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setStencilPattern "Link to this")

playdate.graphics.setStencilPattern(pattern)

Sets a pattern to use for stenciled drawing, as an alternative to creating an image, drawing a pattern into the image, then using that in `setStencilImage()`. `pattern` should be a table of the form `{ row1, row2, row3, row4, row5, row6, row7, row8 }`.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setStencilPattern-rows "Link to this")

playdate.graphics.setStencilPattern(row1, row2, row3, row4, row5, row6, row7, row8)

Sets a pattern to use for stenciled drawing, as an alternative to creating an image, drawing a pattern into the image, then using that in `setStencilImage()`.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setStencilPattern-dither "Link to this")

playdate.graphics.setStencilPattern(level, \[ditherType\])

Sets the stencil to a dither pattern specified by _level_ and optional _ditherType_ (defaults to `playdate.graphics.image.kDitherTypeBayer8x8`).

##### [Link to this](http://sdk.play.date/inside-playdate/\#_drawing_mode "Link to this") Drawing mode

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setImageDrawMode "Link to this")

playdate.graphics.setImageDrawMode(mode)

Sets the current drawing mode for images.

|     |     |
| --- | --- |
| Important | The draw mode applies to images and fonts (which are technically images). The draw mode does not apply to primitive shapes such as lines or rectangles. |

The available options for _mode_ (demonstrated by drawing a two-color background image first, setting the specified draw mode, then drawing the Crankin' character on top) are:

- _playdate.graphics.kDrawModeCopy_: Images are drawn exactly as they are (black pixels are drawn black and white pixels are drawn white)


![drawmode copy](http://sdk.play.date/Inside%20Playdate/drawmode-copy.png)

- _playdate.graphics.kDrawModeWhiteTransparent_: Any white portions of an image are drawn transparent (black pixels are drawn black and white pixels are drawn transparent)


![drawmode whitetransparent](http://sdk.play.date/Inside%20Playdate/drawmode-whitetransparent.png)

- _playdate.graphics.kDrawModeBlackTransparent_: Any black portions of an image are drawn transparent (black pixels are drawn transparent and white pixels are drawn white)


![drawmode blacktransparent](http://sdk.play.date/Inside%20Playdate/drawmode-blacktransparent.png)

- _playdate.graphics.kDrawModeFillWhite_: All non-transparent pixels are drawn white (black pixels are drawn white and white pixels are drawn white)


![drawmode fillwhite](http://sdk.play.date/Inside%20Playdate/drawmode-fillwhite.png)

- _playdate.graphics.kDrawModeFillBlack_: All non-transparent pixels are drawn black (black pixels are drawn black and white pixels are drawn black)


![drawmode fillblack](http://sdk.play.date/Inside%20Playdate/drawmode-fillblack.png)

- _playdate.graphics.kDrawModeXOR_: Pixels are drawn inverted on white backgrounds, creating an effect where any white pixels in the original image will always be visible, regardless of the background color, and any black pixels will appear transparent (on a white background, black pixels are drawn white and white pixels are drawn black)


![drawmode xor](http://sdk.play.date/Inside%20Playdate/drawmode-xor.png)

- _playdate.graphics.kDrawModeNXOR_: Pixels are drawn inverted on black backgrounds, creating an effect where any black pixels in the original image will always be visible, regardless of the background color, and any white pixels will appear transparent (on a black background, black pixels are drawn white and white pixels are drawn black)


![drawmode nxor](http://sdk.play.date/Inside%20Playdate/drawmode-nxor.png)

- _playdate.graphics.kDrawModeInverted_: Pixels are drawn inverted (black pixels are drawn white and white pixels are drawn black)


![drawmode inverted](http://sdk.play.date/Inside%20Playdate/drawmode-inverted.png)

Instead of the above-specified constants, you can also use one of the following strings: "copy", "inverted", "XOR", "NXOR", "whiteTransparent", "blackTransparent", "fillWhite", or "fillBlack".

Equivalent to [`playdate->graphics->setDrawMode()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setDrawMode) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getImageDrawMode "Link to this")

playdate.graphics.getImageDrawMode()

Gets the current drawing mode for images.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_lines_strokes "Link to this") Lines & Strokes

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setLineWidth "Link to this")

playdate.graphics.setLineWidth(width)

Sets the width of the line for [drawLine](http://sdk.play.date#f-graphics.drawLine), [drawRect](http://sdk.play.date#f-graphics.drawRect), [drawPolygon](http://sdk.play.date#f-graphics.drawPolygon), and [drawArc](http://sdk.play.date#f-graphics.drawArc) when a [playdate.geometry.arc](http://sdk.play.date#C-geometry.arc) is passed as the argument. This value is saved and restored when pushing and popping the [graphics context](http://sdk.play.date#f-graphics.pushContext).

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getLineWidth "Link to this")

playdate.graphics.getLineWidth()

Gets the current line width.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setStrokeLocation "Link to this")

playdate.graphics.setStrokeLocation(location)

Specifies where the stroke is placed relative to the rectangle passed into [drawRect](http://sdk.play.date#f-graphics.drawRect).

_location_ is one of these constants:

- _playdate.graphics.kStrokeCentered_

- _playdate.graphics.kStrokeOutside_

- _playdate.graphics.kStrokeInside_


This value is saved and restored when pushing and popping the [graphics context](http://sdk.play.date#f-graphics.pushContext).

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getStrokeLocation "Link to this")

playdate.graphics.getStrokeLocation()

Gets the current stroke position.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_offscreen_drawing "Link to this") Offscreen Drawing

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.lockFocus "Link to this")

playdate.graphics.lockFocus(image)

`lockFocus()` routes all drawing to the given [playdate.graphics.image](http://sdk.play.date#C-graphics.image). [playdate.graphics.unlockFocus()](http://sdk.play.date#f-graphics.unlockFocus) returns drawing to the frame buffer.

|     |     |
| --- | --- |
| Important | If you draw into an image with color set to _playdate.graphics.kColorClear_, those drawn pixels will be set to transparent. When you later draw the image into the framebuffer, those pixels will not be rendered, i.e., will act as transparent pixels in the image. |

|     |     |
| --- | --- |
| Note | [playdate.graphics.pushContext( _image_)](http://sdk.play.date#f-graphics.pushContext) will also allow offscreen drawing into an image, with the additional benefit of being able to save and restore the graphics state. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.unlockFocus "Link to this")

playdate.graphics.unlockFocus()

After calling `unlockFocus()`, drawing is routed to the frame buffer.

Example: Drawing into multiple images with lockFocus

```
-- If you're drawing into multiple different images, using lockFocus might be easier (and
-- slightly faster performance-wise) than having to repeatedly call pushContext/popContext

local tinyCircle = gfx.image.new(10, 10)
local smallCircle = gfx.image.new(20, 20)
local mediumCircle = gfx.image.new(30, 30)
local largeCircle = gfx.image.new(40, 40)

gfx.lockFocus(tinyCircle) -- draw into tinyCircle image
-- Drawing coordinates are relative to the image, so (0, 0) is the top left of the image
gfx.fillCircleInRect(0, 0, tinyCircle:getSize())
gfx.lockFocus(smallCircle) -- draw into smallCircle image
gfx.fillCircleInRect(0, 0, smallCircle:getSize())
gfx.lockFocus(mediumCircle) -- draw into mediumCircle image
gfx.fillCircleInRect(0, 0, mediumCircle:getSize())
gfx.lockFocus(largeCircle) -- draw into largeCircle image
gfx.fillCircleInRect(0, 0, largeCircle:getSize())
gfx.unlockFocus() -- unlock focus to bring drawing back to frame buffer
```

#### [Link to this](http://sdk.play.date/inside-playdate/\#_animation "Link to this") Animation

##### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.animation.loop "Link to this") Animation loop

playdate.graphics.animation.loop helps keep track of animation frames, especially for frames in an [`playdate.graphics.imagetable`](http://sdk.play.date#C-graphics.imagetable). For a more general timer see [playdate.timer](http://sdk.play.date#C-timer) or [playdate.frameTimer](http://sdk.play.date#C-frameTimer).

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/animation_ to use these functions. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.animation.loop.new "Link to this")

playdate.graphics.animation.loop.new(\[interval\], imageTable, \[shouldLoop\])

Creates a new animation object.

- **_imageTable_** must be a [`playdate.graphics.imagetable`](http://sdk.play.date#C-graphics.imagetable) or an array-style table of [`playdate.graphics.images`](http://sdk.play.date#C-graphics.image).


The following properties can be read or set directly, and have these defaults:

- **_interval_** : the value of _interval_, if passed, or 100ms (the elapsed time before advancing to the next imageTable frame)

- **_startFrame_** : 1 (the value the object resets to when the loop completes)

- **_endFrame_** : the number of images in _imageTable_ if passed, or 1 (the last frame value in the loop)

- **_frame_** : 1 (the current frame counter)

- **_step_** : 1 (the value by which frame increments)

- **_shouldLoop_** : the value of _shouldLoop_, if passed, or true. (whether the object loops when it completes)

- **_paused_** : false (paused loops don’t change their frame value)


[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animation.loop.draw "Link to this")

playdate.graphics.animation.loop:draw(x, y, \[flip\])

Draw’s the loop’s current image at _x_, _y_.

The _flip_ argument is optional; see [`playdate.graphics.image:draw()`](http://sdk.play.date#m-graphics.imgDraw) for valid values.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animation.loop.image "Link to this")

playdate.graphics.animation.loop:image()

Returns a [`playdate.graphics.image`](http://sdk.play.date#C-graphics.image) from the caller’s _imageTable_ if it exists. The image returned will be at the imageTable’s index that matches the caller’s _frame_.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animation.loop.isValid "Link to this")

playdate.graphics.animation.loop:isValid()

Returns false if the loop has passed its last frame and does not loop.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animation.loop.setImageTable "Link to this")

playdate.graphics.animation.loop:setImageTable(imageTable)

Sets the [`playdate.graphics.imagetable`](http://sdk.play.date#C-graphics.imagetable) to be used for this animation loop, and sets the loop’s endFrame property to #imageTable.

Example: Using an animation loop to draw an animated image

```
local gfx = playdate.graphics

-- Each frame of the animation will last 200ms
local frameTime = 200
local animationImagetable = gfx.imagetable.new("path/to/imagetable")
-- Setting the last argument to true makes it so the animation will loop
local animationLoop = gfx.animation.loop.new(frameTime, animationImagetable, true)

function playdate.update()
    -- Draws the animation in a loop
    animationLoop:draw(0, 0)
end
```

Example: Creating multiple animation states from one sprite sheet

```
local gfx = playdate.graphics

-- In this example, the imagetable is one sprite sheet, made up of multiple animations
local animationImagetable = gfx.imagetable.new("path/to/imagetable")

-- Creating the idle animation loop (400ms per frame)
local idleAnimation = gfx.animation.loop.new(400, animationImagetable, true)
-- In this example, the idle animation is made of up frames 1 through 3 of the
-- imagetable, so the startFrame and endFrame properties are set accordingly
idleAnimation.startFrame = 1
idleAnimation.endFrame = 3

-- Creating the run animation loop (200ms per frame)
local runAnimation = gfx.animation.loop.new(200, animationImagetable, true)
-- In this example, the run animation is made of up frames 4 through 8 of the
-- imagetable, so the startFrame and endFrame properties are set accordingly
runAnimation.startFrame = 4
runAnimation.endFrame = 8

-- Creating a simple state tracker
local states = {idle = 1, run = 2}
local state = states.idle

function playdate.update()
    -- Draw different animations based on the state
    if state == states.idle then
        idleAnimation:draw(0, 0)
    elseif state == states.run then
        runAnimation:draw(0, 0)
    end
end
```

Example: Using an animation loop in a sprite

```
local gfx = playdate.graphics

-- Each frame of the animation will last 200ms
local frameTime = 200
local animationImagetable = gfx.imagetable.new("path/to/imagetable")
-- Setting the last argument to false makes the animation stop on the last frame
local animationLoop = gfx.animation.loop.new(frameTime, animationImagetable, false)
-- Set sprite image to first frame of the animation
local animatedSprite = gfx.sprite.new(animationLoop:image())
-- Add sprite to display list
animatedSprite:add()
-- One easy way to update the sprite image to match the animation
-- is to simply override the sprite update method and do it there
animatedSprite.update = function()
    animatedSprite:setImage(animationLoop:image())
    -- Optionally, removing the sprite when the animation finished
    if not animationLoop:isValid() then
        animatedSprite:remove()
    end
end
```

##### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.animator "Link to this") Animator

Animators are lightweight objects that keep track of animation progress. They can animate between two numbers, two points, along a line segment, arc, or polygon, or along a compound path made up of all three.

Usage is simple: create a new Animator, query for its current value when you need to update your animation, and optionally call [`animator:ended()`](http://sdk.play.date#m-graphics.animator.ended) to see if the animation is complete.

|     |     |
| --- | --- |
| Tip | Example code: `<Playdate SDK>/Examples/Single File Examples/animator.lua` |

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/animator_ to use these functions. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.animator.new1 "Link to this")

playdate.graphics.animator.new(duration, startValue, endValue, \[easingFunction, \[startTimeOffset\]\])

Animates between two number or [playdate.geometry.point](http://sdk.play.date#C-geometry.point) values.

_duration_ is the total time of the animation in milliseconds.

_startValue_ and _endValue_ should be either numbers or [playdate.geometry.point](http://sdk.play.date#C-geometry.point)

_easingFunction_, if supplied, should be a value from [playdate.easingFunctions](http://sdk.play.date#M-easingFunctions). If your easing function requires additional variables _s_, _a_, or _p_, set them on the animator directly after creation.
For example:

```
local a = playdate.graphics.animator.new(1000, 0, 100, playdate.easingFunctions.inBack)
a.s = 1.9
```

_startTimeOffset_, if supplied, will shift the start time of the animation by the specified number of milliseconds. (If positive, the animation will be delayed. If negative, the animation will effectively have started before the moment the animator is instantiated.)

Example: Using an animator to animate movement

```
-- You can copy and paste this example directly as your main.lua file to see it in action
import "CoreLibs/graphics"
import "CoreLibs/animator"

-- We'll be demonstrating how to use an animator to animate a square moving across the screen
local square = playdate.graphics.image.new(20, 20, playdate.graphics.kColorBlack)

-- 1000ms, or 1 second
local animationDuration = 1000
-- We're animating from the left to the right of the screen
local startX, endX = -20, 400
-- Setting an easing function to get a nice, smooth movement
local easingFunction = playdate.easingFunctions.inOutCubic
local animator = playdate.graphics.animator.new(animationDuration, startX, endX, easingFunction)
animator.repeatCount = -1 -- Make animator repeat forever

function playdate.update()
    -- Clear the screen
    playdate.graphics.clear()

    -- By using :currentValue() as the x value, the square follows along with the animation
    square:draw(animator:currentValue(), 120)
end
```

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.animator.new2 "Link to this")

playdate.graphics.animator.new(duration, lineSegment, \[easingFunction, \[startTimeOffset\]\])

Creates a new Animator that will animate along the provided [playdate.geometry.lineSegment](http://sdk.play.date#C-geometry.lineSegment)

Example: Using an animator to animate along a line

```
-- You can copy and paste this example directly as your main.lua file to see it in action
import "CoreLibs/graphics"
import "CoreLibs/animator"

-- We'll be demonstrating how to use an animator to animate a square moving across the screen
local square = playdate.graphics.image.new(20, 20, playdate.graphics.kColorBlack)

-- 1000ms, or 1 second
local animationDuration = 1000
-- We're animating from the top left to the bottom right of the screen
local line = playdate.geometry.lineSegment.new(0, 0, 400, 240)
local animator = playdate.graphics.animator.new(animationDuration, line)

function playdate.update()
    -- Clear the screen
    playdate.graphics.clear()

    -- We can use :currentValue() directly, as it returns a point
    square:draw(animator:currentValue())
end
```

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.animator.new3 "Link to this")

playdate.graphics.animator.new(duration, arc, \[easingFunction, \[startTimeOffset\]\])

Creates a new Animator that will animate along the provided [playdate.geometry.arc](http://sdk.play.date#C-geometry.arc)

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.animator.new4 "Link to this")

playdate.graphics.animator.new(duration, polygon, \[easingFunction, \[startTimeOffset\]\])

Creates a new Animator that will animate along the provided [playdate.geometry.polygon](http://sdk.play.date#C-geometry.polygon)

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.animator.new5 "Link to this")

playdate.graphics.animator.new(durations, parts, easingFunctions, \[startTimeOffset\])

Creates a new Animator that will animate along each of the items in the _parts_ array in order, which should be comprised of [playdate.geometry.lineSegment](http://sdk.play.date#C-geometry.lineSegment), [playdate.geometry.arc](http://sdk.play.date#C-geometry.arc), or [playdate.geometry.polygon](http://sdk.play.date#C-geometry.polygon) objects.

_durations_ should be an array of durations, one for each item in _parts_.

_easingFunctions_ should be an array of [playdate.easingFunctions](http://sdk.play.date#M-easingFunctions), one for each item in _parts_.

|     |     |
| --- | --- |
| Note | By default, animators do not repeat. If you would like them to, set the animator’s _repeatCount_ property to the number of times the animation should repeat. It can be set to any positive number or -1 to indicate the animation should repeat forever. Note that a repeat count of 1 means the animation will play twice - once for the initial animation plus one repeat. |

Example: Using an animator with parts

```
-- You can copy and paste this example directly as your main.lua file to see it in action
import "CoreLibs/graphics"
import "CoreLibs/animator"

-- We'll be demonstrating how to animate something with parts
local square = playdate.graphics.image.new(20, 20, playdate.graphics.kColorBlack)

-- First part will take 3 seconds, second part will take 1, and third part will take 2
local animationDurations = {3000, 1000, 2000}
-- We'll first animate along a line, then an arc, and then a polygon
local animationParts = {
    playdate.geometry.lineSegment.new(0, 0, 200, 80),
    playdate.geometry.arc.new(200, 120, 40, 0, 180),
    playdate.geometry.polygon.new(200, 160, 300, 90, 390, 230)
}
-- We must set the easing functions for each part, and they can all be different
local animationEasingFunctions = {
    playdate.easingFunctions.outQuart,
    playdate.easingFunctions.inOutCubic,
    playdate.easingFunctions.outBounce
}

-- To animate by parts, each argument must be arrays of equal length
local animator = playdate.graphics.animator.new(animationDurations, animationParts, animationEasingFunctions)

function playdate.update()
    -- Clear the screen
    playdate.graphics.clear()

    -- We can use :currentValue() directly, as it returns a point
    square:draw(animator:currentValue())
end
```

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animator.currentValue "Link to this")

playdate.graphics.animator:currentValue()

Returns the current value of the animation, which will be either a number or a [playdate.geometry.point](http://sdk.play.date#C-geometry.point), depending on the type of animator.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animator.valueAtTime "Link to this")

playdate.graphics.animator:valueAtTime(time)

Returns the value of the animation at the given number of milliseconds after the start time. The value will be either a number or a [playdate.geometry.point](http://sdk.play.date#C-geometry.point), depending on the type of animator.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animator.progress "Link to this")

playdate.graphics.animator:progress()

Returns the current progress of the animation as a value from 0 to 1.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animator.reset "Link to this")

playdate.graphics.animator:reset(\[duration\])

Resets the animation, setting its start time to the current time, and changes the animation’s duration if a new duration is given.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animator.ended "Link to this")

playdate.graphics.animator:ended()

Returns true if the animation is completed. Only returns true if this function or [`currentValue()`](http://sdk.play.date#m-graphics.animator.currentValue) has been called since the animation ended in order to allow animations to fully finish before true is returned.

[Link to this](http://sdk.play.date/inside-playdate/#v-graphics.animator.repeatCount "Link to this")

playdate.graphics.animator.repeatCount

Indicates the number of times after the initial animation the animator should repeat; i.e., if repeatCount is set to 2, the animation will play through 3 times.

[Link to this](http://sdk.play.date/inside-playdate/#v-graphics.animator.reverses "Link to this")

playdate.graphics.animator.reverses

If set to true, after the animation reaches the end, it runs in reverse from the end to the start. The time to complete both the forward and reverse will be _duration_ x 2. Defaults to false.

##### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.animation.blinker "Link to this") Blinker

playdate.graphics.animation.blinker keeps track of a boolean that changes on a timer.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/animation_ to use `blinker`. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.animation.blinker.new "Link to this")

playdate.graphics.animation.blinker.new(\[onDuration, \[offDuration, \[loop, \[cycles, \[default\]\]\]\]\])

Creates a new blinker object. Check the object’s `on` property to determine whether the blinker is on ( `true`) or off ( `false`). The default properties are:

- _onDuration_: 200 (the number of milliseconds the blinker is "on")

- _offDuration_: 200 (the number of milliseconds the blinker is "off")

- _loop_: false (should the blinker restart after completing)

- _cycles_: 6 (the number of changes the blinker goes through before it’s complete)

- _default_: true (the state the blinker will start in. **Note:** if default is `true`, `blinker.on` will return `true` when the blinker is in its _onDuration_ phase. If default is `false`, `blinker.on` will return `false` when the blinker is in its _onDuration_ phase.)


Other informative properties:

- _counter_: Read this property to see which cycle the blinker is on (counts from _n_ down to zero)

- _on_: Read this property to determine the current state of the blinker. The blinker always starts in the state specified by the `default` property.

- _running_: Read this property to see if the blinker is actively running


[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.animation.blinker.updateAll "Link to this")

playdate.graphics.animation.blinker.updateAll()

Updates the state of all valid blinkers by calling [:update()](http://sdk.play.date#m-graphics.animation.blinker.update) on each.

|     |     |
| --- | --- |
| Important | If you intend to use blinkers, be sure to call `:updateAll()` once a cycle, ideally in your game’s [`playdate.update()`](http://sdk.play.date#c-update) function. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animation.blinker.update "Link to this")

playdate.graphics.animation.blinker:update()

Updates the caller’s state.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animation.blinker.start "Link to this")

playdate.graphics.animation.blinker:start(\[onDuration, \[offDuration, \[loop, \[cycles, \[default\]\]\]\]\])

Starts a blinker if it’s not running. Pass values for any property values you wish to modify.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animation.blinker.startLoop "Link to this")

playdate.graphics.animation.blinker:startLoop()

Starts a blinker if it’s not running and sets its `loop` property to true. Equivalent to calling `playdate.graphics.animation.blinker:start(nil, nil, true)`

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animation.blinker.stop "Link to this")

playdate.graphics.animation.blinker:stop()

Stops a blinker if it’s running, returning the blinker’s `on` properly to the default value.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.animation.blinker.stopAll "Link to this")

playdate.graphics.animation.blinker.stopAll()

Stops all blinkers.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.animation.blinker.remove "Link to this")

playdate.graphics.animation.blinker:remove()

Flags the caller for removal from the global list of blinkers

#### [Link to this](http://sdk.play.date/inside-playdate/\#_scrolling "Link to this") Scrolling

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setDrawOffset "Link to this")

playdate.graphics.setDrawOffset(x, y)

`setDrawOffset(x, y)` offsets the origin point for all drawing calls to _x_, _y_ (can be negative). So, for example, if the offset is set to -20, -20, an image drawn at 20, 20 will appear at the origin (in the upper left corner.)

This is useful, for example, for centering a "camera" on a sprite that is moving around a world larger than the screen.

|     |     |
| --- | --- |
| Note | The _x_ and _y_ arguments to `.setDrawOffset()` are always specified in the original, unaltered coordinate system. So, for instance, repeated calls to `playdate.graphics.setDrawOffset(-10, -10)` will leave the draw offset unchanged. Likewise, `.setDrawOffset(0, 0)` will always "disable" the offset. |

|     |     |
| --- | --- |
| Tip | It can be useful to have operations sometimes ignore the draw offsets. For example, you may want to have the score or some other heads-up display appear onscreen apart from scrolling content. A sprite can be set to ignore offsets by calling [playdate.graphics.sprite:setIgnoresDrawOffset(true)](http://sdk.play.date#m-graphics.sprite.setIgnoresDrawOffset). [playdate.graphics.image:drawIgnoringOffsets()](http://sdk.play.date#m-graphics.image.drawIgnoringOffset) lets you render an image using screen coordinates. |

Equivalent to [`playdate->graphics->setDrawOffset()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setDrawOffset) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getDrawOffset "Link to this")

playdate.graphics.getDrawOffset()

`getDrawOffset()` returns multiple values ( _x_, _y_) giving the current draw offset.

|     |     |
| --- | --- |
| Caution | These functions are different from [playdate.display.setOffset()](http://sdk.play.date#f-display.setOffset) and [playdate.display.getOffset()](http://sdk.play.date#f-display.getOffset). |

#### [Link to this](http://sdk.play.date/inside-playdate/\#_frame_buffer "Link to this") Frame buffer

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getDisplayImage "Link to this")

playdate.graphics.getDisplayImage()

Returns a copy the contents of the _last completed frame_, i.e., a "screenshot", as a [playdate.graphics.image](http://sdk.play.date#C-graphics.image).

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getWorkingImage "Link to this")

playdate.graphics.getWorkingImage()

Returns a copy the contents of the working frame buffer — _the current frame, in-progress_ — as a [playdate.graphics.image](http://sdk.play.date#C-graphics.image).

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.imagetable "Link to this") Image table

There are two kinds of image tables: **matrix** and **sequential**.

**Matrix image tables** are great as sources of imagery for [tilemap](http://sdk.play.date#C-graphics.tilemap). They are loaded from a single file in your game’s source folder with the suffix `-table-<w>-<h>` before the file extension. The compiler splits the image into separate bitmaps of dimension _w_ by _h_ pixels that are accessible via [imagetable:getImage(x,y)](http://sdk.play.date#m-graphics.imagetable.getImage-xy).

**Sequential image tables** are useful as a way to load up sequential frames of animation. They are loaded from a sequence of files in your game’s source folder _at compile time_ from filenames with the suffix `-table-<sequenceNumber>` before the file extension. Individual images in the sequence are accessible via [imagetable:getImage(n)](http://sdk.play.date#m-graphics.imagetable.getImage-n). The images employed by a sequential image table are not required to be the same size, unlike the images used in a matrix image table.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.imagetable.new "Link to this")

playdate.graphics.imagetable.new(path)

Returns a [playdate.graphics.imagetable](http://sdk.play.date#C-graphics.imagetable) object from the data at _path_. If there is no file at _path_, the function returns nil and a second value describing the error. If the file at _path_ is an animated GIF, successive frames of the GIF will be loaded as consecutive bitmaps in the imagetable. Any timing data in the animated GIF will be ignored.

|     |     |
| --- | --- |
| Important | To load a **matrix** image table defined in `frames-table-16-16.png`, you call `playdate.graphics.imagetable.new("frames")`. |

|     |     |
| --- | --- |
| Important | To load a **sequential** image table defined with the files `frames-table-1.png`, `frames-table-2.png`, etc., you call `playdate.graphics.imagetable.new("frames")`. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.imagetable.new-alloc "Link to this")

playdate.graphics.imagetable.new(count, \[cellsWide\], \[cellSize\])

Returns an empty image table for loading images into via [imagetable:load()](http://sdk.play.date#m-graphics.imagetable.load) or setting already-loaded images into with [imagetable:setImage()](http://sdk.play.date#m-graphics.imagetable.setImage). If set, _cellsWide_ is used to locate images by x,y position. The optional _cellSize_ argument gives the allocation size for the images, if [load()](http://sdk.play.date#m-graphics.imagetable.load) will be used. (This is a weird technical detail, so ask us if you need guidance here.)

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.imagetable.getImage-n "Link to this")

playdate.graphics.imagetable:getImage(n)

Returns the _n_-th [playdate.graphics.image](http://sdk.play.date#C-graphics.image) in the table (ordering left-to-right, top-to-bottom). The first image is at index 1. If .n\_ or ( _x_, _y_) is out of bounds, the function returns nil. See also [imagetable\[n\]](http://sdk.play.date#m-graphics.imagetable.__len).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.imagetable.getImage-xy "Link to this")

playdate.graphics.imagetable:getImage(x,y)

Returns the image in cell ( _x_, _y_) in the original bitmap. The first image is at index 1. If _n_ or ( _x_, _y_) is out of bounds, the function returns nil. See also [imagetable\[n\]](http://sdk.play.date#m-graphics.imagetable.__len).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.imagetable.setImage "Link to this")

playdate.graphics.imagetable:setImage(n, image)

Sets the image at slot _n_ in the image table by creating a reference to the data in _image_.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.imagetable.load "Link to this")

playdate.graphics.imagetable:load(path)

Loads a new image table from the data at _path_ into an already-existing image table, without allocating additional memory. The image table at _path_ must contain images of the same dimensions as the previous.

Returns `(success, [error])`. If the boolean `success` is false, `error` is also returned.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.imagetable.getSize "Link to this")

playdate.graphics.imagetable:getSize()

Returns the pair ( _cellsWide_, _cellsHigh_).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.imagetable.drawImage "Link to this")

playdate.graphics.imagetable:drawImage(n,x,y,\[flip\])

Equivalent to `graphics.imagetable:getImage(n):draw(x,y,[flip])`.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.imagetable.__index "Link to this")

playdate.graphics.imagetable\[n\]

Equivalent to [imagetable:getImage(n)](http://sdk.play.date#m-graphics.imagetable.getImage-n).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.imagetable.__len "Link to this")

#playdate.graphics.imagetable

Equivalent to [imagetable:getLength()](http://sdk.play.date#m-graphics.imagetable.getLength)

|     |     |
| --- | --- |
| Tip | In Lua, you can get the length of a string or table using the [length operator](http://www.lua.org/manual/5.1/manual.html#2.5.5). For a `playdate.graphics.imagetable` called `myImageTable`, both `#myImageTable` and `myImageTable:getLength()` would return the same result. |

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.tilemap "Link to this") Tilemap

Tilemaps are often used to represent the game environment. Tiles are a very efficient way to create levels and scenery. (Alternatively, [sprites](http://sdk.play.date#C-graphics.sprite) are the best way to create objects that move about your playfield, like the character that represents the player, enemies, etc.)

At its most fundamental, a tilemap is a table of indexes into an [playdate.graphics.imagetable](http://sdk.play.date#C-graphics.imagetable). The images in the imagetable represent small chunks of your scenery; the tilemap is what organizes them into a specific arrangement.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_how_to "Link to this") How-To

A typical usage of tilemaps might be to assist in drawing a game level:

1. Instantiate a blank [tilemap](http://sdk.play.date#f-graphics.tilemap.new).

2. Attach an [imagetable](http://sdk.play.date#m-graphics.tilemap.setImageTable) — a matrix of tile images that your game level will utilize.

3. Set your tilemap’s matrix of indices — these represent your game level — into the imagetable using [:setTiles()](http://sdk.play.date#m-graphics.tilemap.setTiles). (A tilemap editor such as [Tiled](https://www.mapeditor.org) can be very useful for this.) This is also where you specify your tilemap’s width.

4. Draw your tilemap using [:draw()](http://sdk.play.date#m-graphics.tilemap.draw).


##### [Link to this](http://sdk.play.date/inside-playdate/\#_configuring "Link to this") Configuring

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.tilemap.new "Link to this")

playdate.graphics.tilemap.new()

Creates a new tilemap object.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.setImageTable "Link to this")

playdate.graphics.tilemap:setImageTable(table)

Sets the tilemap’s [playdate.graphics.imagetable](http://sdk.play.date#C-graphics.imagetable) to _table_, a [playdate.graphics.imagetable](http://sdk.play.date#C-graphics.imagetable).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.getSize "Link to this")

playdate.graphics.tilemap:getSize()

Returns the size of the tilemap, in tiles, as a pair, ( _width_, _height_).

##### [Link to this](http://sdk.play.date/inside-playdate/\#_setting_tile_values "Link to this") Setting tile values

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.setTiles "Link to this")

playdate.graphics.tilemap:setTiles(data, width)

Sets the tilemap’s width to _width_, then populates the tilemap with _data_, which should be a flat, one-dimensional array-like table containing index values to the [tilemap’s imagetable](http://sdk.play.date#m-graphics.tilemap.setImageTable).

|     |     |
| --- | --- |
| Tip | This function is especially useful for configuring a large number of tiles at once — say when first loading a game level. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.getTiles "Link to this")

playdate.graphics.tilemap:getTiles()

Returns _data_, _width_

_data_ is a flat, one-dimensional array-like table containing index values to the [tilemap’s imagetable](http://sdk.play.date#m-graphics.tilemap.setImageTable).

_width_ is the width of the tilemap, in number of tiles.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.setTileAtPosition "Link to this")

playdate.graphics.tilemap:setTileAtPosition(x, y, index)

Sets the index of the tile at tilemap position ( _x_, _y_). _index_ is the (1-based) index of the image in the tilemap’s [playdate.graphics.imagetable](http://sdk.play.date#C-graphics.imagetable).

|     |     |
| --- | --- |
| Tip | This function is especially useful for making small adjustments to existing tilemaps — say, if the state of a tile changes during gameplay. |

|     |     |
| --- | --- |
| Important | Tilemaps and imagetables, like Lua arrays, are 1-based, not 0-based. `tilemap:setTileAtPosition(1, 1, 2)` will set the index of the tile in the top-leftmost position to 2. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.getTileAtPosition "Link to this")

playdate.graphics.tilemap:getTileAtPosition(x, y)

Returns the image index of the tile at the given _x_ and _y_ coordinate. If _x_ or _y_ is out of bounds, returns nil.

|     |     |
| --- | --- |
| Important | Tilemaps and imagetables, like Lua arrays, are 1-based, not 0-based. `tilemap:getTileAtPosition(1, 1)` will return the index of the top-leftmost tile. |

##### [Link to this](http://sdk.play.date/inside-playdate/\#_drawing_2 "Link to this") Drawing

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.draw "Link to this")

playdate.graphics.tilemap:draw(x, y, \[sourceRect\])

Draws the tilemap at screen coordinate ( _x_, _y_).

_sourceRect_, if specified, will cause only the part of the tilemap within sourceRect to be drawn. _sourceRect_ should be relative to the tilemap’s bounds and can be a [playdate.geometry.rect](http://sdk.play.date#C-geometry.rect) or four integers, ( _x_, _y_, _w_, _h_), representing the rect.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_collisions "Link to this") Collisions

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.getCollisionRects "Link to this")

playdate.graphics.tilemap:getCollisionRects(emptyIDs)

This function returns an array of [playdate.geometry.rect](http://sdk.play.date#C-geometry.rect) objects that describe the areas of the tilemap that should trigger collisions. You can also think of them as the "impassable" rects of your tilemap. These rects will be in tilemap coordinates, not pixel coordinates.

_emptyIDs_ is an array that contains the tile IDs of "empty" (or "passable") tiles in the tilemap — in other words, tile IDs that should not trigger a collision. Tiles with default IDs of 0 are treated as empty by default, so you do not need to include 0 in the array.

For example, if you have a tilemap describing terrain, where tile ID 1 represents grass the player can walk over, and tile ID 2 represents mountains that the player can’t cross, you’d pass an array containing just the value 1. You’ll get a back an array of a minimal number of rects describing the areas where there are mountain tiles.

You can then pass each of those rects into [playdate.graphics.sprite.addEmptyCollisionSprite()](http://sdk.play.date#f-graphics.sprite.addEmptyCollisionSprite) to add an empty (invisible) sprite into the scene for the built-in collision detection methods. In this example, collide rects would be added around mountain tiles but not grass tiles.

Alternatively, instead of calling getCollisionRects() at all, you can use the convenience function [playdate.graphics.sprite.addWallSprites()](http://sdk.play.date#f-graphics.sprite.addWallSprites), which is effectively a shortcut for calling getCollisionRects() and passing all the resulting rects to [addEmptyCollisionSprite()](http://sdk.play.date#f-graphics.sprite.addEmptyCollisionSprite).

##### [Link to this](http://sdk.play.date/inside-playdate/\#_other_tilemap_functions "Link to this") Other tilemap functions

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.getPixelSize "Link to this")

playdate.graphics.tilemap:getPixelSize()

Returns the size of the tilemap in pixels; that is, the size of the image multiplied by the number of rows and columns in the map. Returns multiple values ( _width_, _height_).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.tilemap.getTileSize "Link to this")

playdate.graphics.tilemap:getTileSize()

Returns two values ( _width_, _height_), the pixel width and height of an individual tile.

These values are determined by the tile size of the associated [imagetable](http://sdk.play.date#m-graphics.tilemap.setImageTable) and are not otherwise configurable.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.sprite "Link to this") Sprite

Sprites are graphic objects that can be used to represent moving entities in your games, like the player, or the enemies that chase after your player. Sprites animate efficiently, and offer collision detection and a host of other built-in functionality. (If you want to create an environment for your sprites to move around in, consider using [tilemaps](http://sdk.play.date#C-graphics.tilemap) or [drawing a background image](http://sdk.play.date#f-graphics.sprite.setBackgroundDrawingCallback).)

|     |     |
| --- | --- |
| Note | To have access to all the sprite functionality described below, be sure to `import "CoreLibs/sprites"` at the top of your source file. |

The simplest way to create a sprite is using `sprite.new(image)`:

Creating a standalone sprite

```
import "CoreLibs/sprites"

local image = playdate.graphics.image.new("coin")
local sprite = playdate.graphics.sprite.new(image)
sprite:moveTo(100, 100)
sprite:add()
```

If you want to use an object-oriented approach, you can also subclass sprites and create instance of those subclasses.

Creating a sprite subclass

```
import "CoreLibs/sprites"

class('MySprite').extends(playdate.graphics.sprite)

local sprite = MySprite()
local image = playdate.graphics.image.new("coin")
sprite:setImage(image)
sprite:moveTo(100, 100)
sprite:add()
```

Or with a custom initializer:

Creating a sprite subclass with a custom initializer

```
import "CoreLibs/sprites"

class('MySprite').extends(playdate.graphics.sprite)

local image = playdate.graphics.image.new("coin")

function MySprite:init(x, y)
    MySprite.super.init(self) -- this is critical
    self:setImage(image)
    self:moveTo(x, y)
end

local sprite = MySprite(100, 100)
sprite:add()
```

##### [Link to this](http://sdk.play.date/inside-playdate/\#_sprite_basics "Link to this") Sprite Basics

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.new "Link to this")

playdate.graphics.sprite.new(\[image\_or\_tilemap\])

|     |     |
| --- | --- |
| Important | To see your sprite onscreen, you will need to call [`:add()`](http://sdk.play.date#m-graphics.sprite.add) on your sprite to add it to the display list. |

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.spriteWithText "Link to this")

playdate.graphics.sprite.spriteWithText(text, maxWidth, maxHeight, \[backgroundColor, \[leadingAdjustment, \[truncationString, \[alignment, \[font\]\]\]\]\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/sprites_ to use this function. |

A conveneince function that creates a sprite with an image of `text`, as generated by [imageWithText()](http://sdk.play.date#f-graphics.imageWithText).

The arguments are the same as those in [imageWithText()](http://sdk.play.date#f-graphics.imageWithText).

Returns `sprite`, `textWasTruncated`

`sprite` is a newly-created [sprite](http://sdk.play.date#C-graphics.sprite) with its image set to an image of the text specified. The sprite’s dimensions may be smaller than `maxWidth`, `maxHeight`.

`textWasTruncated` indicates if the text was truncated to fit within the specified width and height.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.update "Link to this")

playdate.graphics.sprite.update()

This class method (note the "." syntax rather than ":") calls the [update()](http://sdk.play.date#c-graphics.sprite.update) function on every sprite in the global sprite list and redraws all of the dirty rects.

|     |     |
| --- | --- |
| Important | You will generally want to call `playdate.graphics.sprite.update()` once in your [`playdate.update()`](http://sdk.play.date#c-update) method, to ensure that your sprites are updated and drawn during every frame. Failure to do so may mean your sprites will not appear onscreen. |

|     |     |
| --- | --- |
| Caution | Be careful not confuse `sprite.update()` with [`sprite:update()`](http://sdk.play.date#c-graphics.sprite.update): the former updates all sprites; the latter updates just the sprite being invoked. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setImage "Link to this")

playdate.graphics.sprite:setImage(image, \[flip, \[scale, \[yscale\]\]\])

Sets the sprite’s image to `image`, which should be an instance of [playdate.graphics.image](http://sdk.play.date#C-graphics.image). The .flip\_ argument is optional; see [playdate.graphics.image:draw()](http://sdk.play.date#m-graphics.imgDraw) for valid values. Optional scale arguments are also accepted. Unless disabled with [playdate.graphics.sprite:setRedrawOnImageChange()](http://sdk.play.date#m-graphics.sprite.setRedrawsOnImageChange), the sprite is automatically marked for redraw if the image isn’t the previous image.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getImage "Link to this")

playdate.graphics.sprite:getImage()

Returns the playdate.graphics.image object that was set with setImage().

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.add "Link to this")

playdate.graphics.sprite:add()

Adds the given sprite to the display list, so that it is drawn in the current scene.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.addSprite "Link to this")

playdate.graphics.sprite.addSprite(sprite)

Adds the given sprite to the display list, so that it is drawn in the current scene. Note that this is called with a period `.` instead of a colon `:`.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.remove "Link to this")

playdate.graphics.sprite:remove()

Removes the given sprite from the display list.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.removeSprite "Link to this")

playdate.graphics.sprite.removeSprite(sprite)

Removes the given sprite from the display list. As with `add()`/ `addSprite()`, note that this is called with a period `.` instead of a colon `:`.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.moveTo "Link to this")

playdate.graphics.sprite:moveTo(x, y)

Moves the sprite and resets the bounds based on the image dimensions and center.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getPosition "Link to this")

playdate.graphics.sprite:getPosition()

Returns the sprite’s current x, y position as multiple values ( _x_, _y_).

[Link to this](http://sdk.play.date/inside-playdate/#a-graphics.sprite.x "Link to this")

playdate.graphics.sprite.x

Can be used to directly read your sprite’s x position.

[Link to this](http://sdk.play.date/inside-playdate/#a-graphics.sprite.y "Link to this")

playdate.graphics.sprite.y

Can be used to directly read your sprite’s y position.

|     |     |
| --- | --- |
| Caution | Do not set these properties directly. Use [`:moveTo()`](http://sdk.play.date#m-graphics.sprite.moveTo) instead. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.moveBy "Link to this")

playdate.graphics.sprite:moveBy(x, y)

Moves the sprite by _x_, _y_ pixels relative to its current position.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setZIndex "Link to this")

playdate.graphics.sprite:setZIndex(z)

Sets the Z-index of the given sprite. Sprites with higher Z-indexes are drawn on top of those with lower Z-indexes. Valid values for _z_ are in the range (-32768, 32767).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getZIndex "Link to this")

playdate.graphics.sprite:getZIndex()

Returns the Z-index of the given sprite.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.isVisible "Link to this")

playdate.graphics.sprite:isVisible()

Returns a boolean value, true if the sprite is visible.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setCenter "Link to this")

playdate.graphics.sprite:setCenter(x, y)

Sets the sprite’s drawing center as a fraction (ranging from 0.0 to 1.0) of the height and width. Default is 0.5, 0.5 (the center of the sprite). This means that when you call [:moveTo(x, y)](http://sdk.play.date#m-graphics.sprite.moveTo), the center of your sprite will be positioned at _x_, _y_. If you want x and y to represent the upper left corner of your sprite, specify the center as 0, 0.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getCenter "Link to this")

playdate.graphics.sprite:getCenter()

Returns multiple values ( `x, y`) representing the sprite’s drawing center as a fraction (ranging from 0.0 to 1.0) of the height and width.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getCenterPoint "Link to this")

playdate.graphics.sprite:getCenterPoint()

Returns a [playdate.geometry.point](http://sdk.play.date#C-geometry.point) representing the sprite’s drawing center as a fraction (ranging from 0.0 to 1.0) of the height and width.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setSize "Link to this")

playdate.graphics.sprite:setSize(width, height)

Sets the sprite’s size. The method has no effect if the sprite has an image set.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getSize "Link to this")

playdate.graphics.sprite:getSize()

Returns multiple values _(width, height)_, the current size of the sprite.

[Link to this](http://sdk.play.date/inside-playdate/#a-graphics.sprite.width "Link to this")

playdate.graphics.sprite.width

Can be used to directly read your sprite’s width.

[Link to this](http://sdk.play.date/inside-playdate/#a-graphics.sprite.height "Link to this")

playdate.graphics.sprite.height

Can be used to directly read your sprite’s height.

|     |     |
| --- | --- |
| Caution | Do not set these properties directly. Use [`:setSize()`](http://sdk.play.date#m-graphics.sprite.setSize) instead. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setScale "Link to this")

playdate.graphics.sprite:setScale(scale, \[yScale\])

Sets the scaling factor for the sprite, with an optional separate scaling for the y axis. If setImage() is called after this, the scale factor is applied to the new image. Only affects sprites that have an image set.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getScale "Link to this")

playdate.graphics.sprite:getScale()

Returns multiple values _(xScale, yScale)_, the current scaling of the sprite.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setRotation "Link to this")

playdate.graphics.sprite:setRotation(angle, \[scale, \[yScale\]\])

Sets the rotation for the sprite, in degrees clockwise, with an optional scaling factor. If setImage() is called after this, the rotation and scale is applied to the new image. Only affects sprites that have an image set. This function should be used with discretion, as it’s likely to be slow on the hardware. Consider pre-rendering rotated images for your sprites instead.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getRotation "Link to this")

playdate.graphics.sprite:getRotation()

Returns the current rotation of the sprite.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.copy "Link to this")

playdate.graphics.sprite:copy()

Returns a copy of the caller.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setUpdatesEnabled "Link to this")

playdate.graphics.sprite:setUpdatesEnabled(flag)

The sprite’s _updatesEnabled_ flag (defaults to true) determines whether a sprite’s [update()](http://sdk.play.date#c-graphics.sprite.update) method will be called. By default, a sprite’s `update` method does nothing; however, you may choose to have your sprite do something on every frame by implementing an update method on your sprite instance, or implementing it in your sprite subclass.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.updatesEnabled "Link to this")

playdate.graphics.sprite:updatesEnabled()

Returns a boolean value, true if updates are enabled on the sprite.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setTag "Link to this")

playdate.graphics.sprite:setTag(tag)

Sets the sprite’s tag, an integer value in the range of 0 to 255, useful for identifying sprites later, particularly when working with collisions.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getTag "Link to this")

playdate.graphics.sprite:getTag()

Returns the sprite’s tag, an integer value.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setImageDrawMode "Link to this")

playdate.graphics.sprite:setImageDrawMode(mode)

Sets the mode for drawing the bitmap. See [playdate.graphics.setImageDrawMode(mode)](http://sdk.play.date#f-graphics.setImageDrawMode) for valid modes.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setImageFlip "Link to this")

playdate.graphics.sprite:setImageFlip(flip, \[flipCollideRect\])

Flips the bitmap. See [playdate.graphics.image:draw()](http://sdk.play.date#m-graphics.imgDraw) for valid `flip` values.

If `true` is passed for the optional _flipCollideRect_ argument, the sprite’s collideRect will be flipped as well.

Calling setImage() will reset the sprite to its default, non-flipped orientation. So, if you call both setImage() and setImageFlip(), call setImage() first.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getImageFlip "Link to this")

playdate.graphics.sprite:getImageFlip()

Returns one of the values listed at [playdate.graphics.image:draw()](http://sdk.play.date#m-graphics.imgDraw).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setIgnoresDrawOffset "Link to this")

playdate.graphics.sprite:setIgnoresDrawOffset(flag)

When set to _true_, the sprite will draw in screen coordinates, ignoring the currently-set [_drawOffset_](http://sdk.play.date#f-graphics.setDrawOffset).

This only affects drawing, and should not be used on sprites being used for collisions, which will still happen in world-space.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setBounds "Link to this")

playdate.graphics.sprite:setBounds(upper-left-x, upper-left-y, width, height)

`setBounds()` positions and sizes the sprite, used for drawing and for calculating dirty rects. _upper-left-x_ and _upper-left-y_ are relative to the overall display coordinate system. (If an image is attached to the sprite, the size will be defined by that image, and not by the _width_ and _height_ parameters passed in to `setBounds()`.)

|     |     |
| --- | --- |
| Note | In `setBounds()`, _x_ and _y_ always correspond to the upper left corner of the sprite, regardless of how a [sprite’s center](http://sdk.play.date#m-graphics.sprite.setCenter) is defined. This makes it different from [sprite:moveTo()](http://sdk.play.date#m-graphics.sprite.moveTo), where _x_ and _y_ honor the sprite’s defined center (by default, at a point 50% along the sprite’s width and height.) |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setBounds-rect "Link to this")

playdate.graphics.sprite:setBounds(rect)

`setBounds(rect)` sets the bounds of the sprite with a [`playdate.geometry.rect`](http://sdk.play.date#C-geometry.rect) object.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getBounds "Link to this")

playdate.graphics.sprite:getBounds()

`getBounds()` returns multiple values ( _x_, _y_, _width_, _height_).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getBoundsRect "Link to this")

playdate.graphics.sprite:getBoundsRect()

`getBoundsRect()` returns the sprite bounds as a [`playdate.geometry.rect`](http://sdk.play.date#C-geometry.rect) object.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setOpaque "Link to this")

playdate.graphics.sprite:setOpaque(flag)

Marking a sprite opaque tells the sprite system that it doesn’t need to draw anything underneath the sprite, since it will be overdrawn anyway. If you set an image without a mask/alpha channel on the sprite, it automatically sets the opaque flag.

Setting a sprite to opaque can have performance benefits.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.isOpaque "Link to this")

playdate.graphics.sprite:isOpaque()

Returns the sprite’s current opaque flag.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_drawing_images_alongside_sprites "Link to this") Drawing images alongside sprites

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.setBackgroundDrawingCallback "Link to this")

playdate.graphics.sprite.setBackgroundDrawingCallback(drawCallback)

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/sprites_ to use this function. |

A convenience function for drawing a background image behind your sprites.

_drawCallback_ is a routine you specify that implements your background drawing. The callback should be a function taking the arguments `x, y, width, height`, where _x, y, width, height_ specify the region (in screen coordinates, not world coordinates) of the background region that needs to be updated.

|     |     |
| --- | --- |
| Note | Some implementation details: `setBackgroundDrawingCallback()` creates a screen-sized sprite with a z-index set to the lowest possible value so it will draw behind other sprites, and adds the sprite to the display list so that it is drawn in the current scene. The background sprite ignores the [drawOffset](http://sdk.play.date#f-graphics.setDrawOffset), and will not be automatically redrawn when the draw offset changes; use [playdate.graphics.sprite.redrawBackground()](http://sdk.play.date#f-graphics.sprite.redrawBackground) if necessary in this case. _drawCallback_ will be called from the newly-created background sprite’s [playdate.graphics.sprite:draw()](http://sdk.play.date#c-graphics.sprite.draw) callback function and is where you should do your background drawing. This function returns the newly created [playdate.graphics.sprite](http://sdk.play.date#C-graphics.sprite). |

For additional background, here is the implementation of `setBackgroundDrawingCallback()` in the Playdate SDK. (This does _not_ reflect how you should use `setBackgroundDrawingCallback()` in your game. For an example of game usage, see [A Basic Playdate Game in Lua](http://sdk.play.date#basic-playdate-game).)

```
function playdate.graphics.sprite.setBackgroundDrawingCallback(drawCallback)
        local bgsprite = gfx.sprite.new()
        bgsprite:setSize(playdate.display.getSize())
        bgsprite:setCenter(0, 0)
        bgsprite:moveTo(0, 0)
        bgsprite:setZIndex(-32768)
        bgsprite:setIgnoresDrawOffset(true)
        bgsprite:setUpdatesEnabled(false)
        bgsprite.draw = function(s, x, y, w, h)
                drawCallback(x, y, w, h)
        end
        bgsprite:add()
        return bgsprite
end
```

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.redrawBackground "Link to this")

playdate.graphics.sprite.redrawBackground()

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/sprites_ to use this function. |

Marks the background sprite dirty, forcing the drawing callback to be run when [playdate.graphics.sprite.update()](http://sdk.play.date#f-graphics.sprite.update) is called.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setTilemap "Link to this")

playdate.graphics.sprite:setTilemap(tilemap)

Sets the sprite’s contents to the given [tilemap](http://sdk.play.date#C-graphics.tilemap). Useful if you want to automate drawing of your tilemap, especially if interleaved by depth with other sprites being drawn.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_automatically_animating_sprites "Link to this") Automatically animating sprites

While it is customary to move sprites around onscreen by calling `sprite:moveTo(x, y)` on successive `playdate.update()` calls, it is possible to automate animation behavior with the use of [animators](http://sdk.play.date#C-graphics.animator).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setAnimator "Link to this")

playdate.graphics.sprite:setAnimator(animator, \[moveWithCollisions, \[removeOnCollision\]\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/sprites_ to use the `setAnimator` method. |

`setAnimator` assigns an [playdate.graphics.animator](http://sdk.play.date#C-graphics.animator) to the sprite, which will cause the sprite to automatically update its position each frame while the animator is active.

_animator_ should be a [playdate.graphics.animator](http://sdk.play.date#C-graphics.animator) created using [playdate.geometry.point](http://sdk.play.date#C-geometry.point) s for its start and end values.

_movesWithCollisions_, if provided and true will cause the sprite to move with collisions. A collision rect must be set on the sprite prior to passing true for this argument.

_removeOnCollision_, if provided and true will cause the animator to be removed from the sprite when a collision occurs.

|     |     |
| --- | --- |
| Note | `setAnimator` should be called only after any custom update method has been set on the sprite. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.removeAnimator "Link to this")

playdate.graphics.sprite:removeAnimator()

Removes a [playdate.graphics.animator](http://sdk.play.date#C-graphics.animator) assigned to the sprite

Example: Setting an animator on a sprite

```
-- You can copy and paste this example directly as your main.lua file to see it in action
import "CoreLibs/animator"
import "CoreLibs/sprites"

-- We'll be demonstrating how to use an animator to animate a sprite
local square = playdate.graphics.image.new(20, 20, playdate.graphics.kColorBlack)
local squareSprite = playdate.graphics.sprite.new(square)
squareSprite:add()

-- 4000ms, or 4 seconds
local animationDuration = 4000
-- We're animating in a rectangle, around the screen. The animator must be animating along some geometry
-- or between two points if used on a sprite - just animating between two values will result in an error
local polygon = playdate.geometry.polygon.new(20, 20, 380, 20, 380, 220, 20, 220, 20, 20)
-- Setting an easing function to get a nice, smooth movement
local easingFunction = playdate.easingFunctions.inOutCubic
local animator = playdate.graphics.animator.new(animationDuration, polygon, easingFunction)

-- Setting the animator on the sprite to move it
squareSprite:setAnimator(animator)

function playdate.update()
    -- Everything is handled automatically, provided you call the sprite update function
    playdate.graphics.sprite.update()

    -- Set to and stays true on animation end - will print continuously when the animation finishes
    if animator:ended() then
        print("Animation ended!")
    end
end
```

##### [Link to this](http://sdk.play.date/inside-playdate/\#_clipping_2 "Link to this") Clipping

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setClipRect "Link to this")

playdate.graphics.sprite:setClipRect(x, y, width, height)

playdate.graphics.sprite:setClipRect(rect)

Sets the clipping rectangle for the sprite, using separate parameters or a [`playdate.geometry.rect`](http://sdk.play.date#C-geometry.rect) object. Only areas within the rect will be drawn.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.clearClipRect "Link to this")

playdate.graphics.sprite:clearClipRect()

Clears the sprite’s current clipping rectangle.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.setClipRectsInRange "Link to this")

playdate.graphics.sprite.setClipRectsInRange(x, y, width, height, startz, endz)

playdate.graphics.sprite.setClipRectsInRange(rect, startz, endz)

Sets the clip rect for sprites in the given z-index range.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.clearClipRectsInRange "Link to this")

playdate.graphics.sprite.clearClipRectsInRange(startz, endz)

Clears sprite clip rects in the given z-index range.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setStencilImage "Link to this")

playdate.graphics.sprite:setStencilImage(stencil, \[tile\])

Specifies a stencil image to be set before the sprite is drawn. As with [playdate.graphics.setStencilImage()](http://sdk.play.date#f-graphics.setStencilImage), the sprite pixels will be drawn where the stencil is white and nothing drawn where the stencil is black. Note that the stencil is attached to the frame buffer (i.e., the screen), not the sprite—it does not move along with the sprite. If _tile_ is set, the stencil will be tiled; in this case, the image width must be a multiple of 32 pixels.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setStencilPattern "Link to this")

playdate.graphics.setStencilPattern({ row1, row2, row3, row4, row5, row6, row7, row8 })

Sets the sprite’s stencil to the given pattern, tiled across the screen.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setStencilPattern_p "Link to this")

playdate.graphics.setStencilPattern(pattern)

Sets the sprite’s stencil to the given pattern, tiled across the screen. `pattern` should be a table of the form `{ row1, row2, row3, row4, row5, row6, row7, row8 }`.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setStencilPattern-dither "Link to this")

playdate.graphics.sprite:setStencilPattern(level, \[ditherType\])

Sets the sprite’s stencil to a dither pattern specified by _level_ and optional _ditherType_ (defaults to `playdate.graphics.image.kDitherTypeBayer8x8`).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.clearStencil "Link to this")

playdate.graphics.sprite:clearStencil()

Clears the sprite’s stencil.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_drawing_3 "Link to this") Drawing

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.setAlwaysRedraw "Link to this")

playdate.graphics.sprite.setAlwaysRedraw(flag)

If set to true, causes all sprites to draw each frame, whether or not they have been marked dirty. This may speed up the performance of your game if the system’s dirty rect tracking is taking up too much time - for example if there are many sprites moving around on screen at once.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.getAlwaysRedraw "Link to this")

playdate.graphics.sprite.getAlwaysRedraw()

Return’s the sprites "always redraw" flag.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.markDirty "Link to this")

playdate.graphics.sprite:markDirty()

Marks the rect defined by the sprite’s current bounds as needing a redraw.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.addDirtyRect "Link to this")

playdate.graphics.sprite.addDirtyRect(x, y, width, height)

Marks the given rectangle (in screen coordinates) as needing a redraw. playdate.graphics drawing functions now call this automatically, adding their drawn areas to the sprite’s dirty list, so there’s likely no need to call this manually any more. This behavior may change in the future, though.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setRedrawsOnImageChange "Link to this")

playdate.graphics.sprite:setRedrawsOnImageChange(flag)

By default, sprites are automatically marked for redraw when their image is changed via [playdate.graphics.sprite:setImage()](http://sdk.play.date#m-graphics.sprite.setImage). If disabled by calling this function with a _false_ argument, [playdate.graphics.sprite.addDirtyRect()](http://sdk.play.date#m-graphics.sprite.addDirtyRect) can be used to mark the (potentially smaller) area of the screen that needs to be redrawn.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_group_operations "Link to this") Group operations

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.getAllSprites "Link to this")

playdate.graphics.sprite.getAllSprites()

Returns an array of all sprites in the display list.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.performOnAllSprites "Link to this")

playdate.graphics.sprite.performOnAllSprites(f)

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/sprites_ to use this function. |

Performs the function _f_ on all sprites in the display list. _f_ should take one argument, which will be a sprite.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.spriteCount "Link to this")

playdate.graphics.sprite.spriteCount()

Returns the number of sprites in the display list.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.removeAll "Link to this")

playdate.graphics.sprite.removeAll()

Removes all sprites from the global sprite list.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.removeSprites "Link to this")

playdate.graphics.sprite.removeSprites(spriteArray)

Removes all sprites in `spriteArray` from the global sprite list.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_sprite_callbacks "Link to this") Sprite callbacks

[Link to this](http://sdk.play.date/inside-playdate/#c-graphics.sprite.draw "Link to this")

playdate.graphics.sprite:draw(x, y, width, height)

If the sprite doesn’t have an image, the sprite’s draw function is called as needed to update the display. The rect passed in is the current dirty rect being updated by the display list. The rect coordinates passed in are relative to the sprite itself (i.e. x = 0, y = 0 refers to the top left corner of the sprite). Note that the callback is only called when the sprite is on screen and has a size specified via [sprite:setSize()](http://sdk.play.date#m-graphics.sprite.setSize) or [sprite:setBounds()](http://sdk.play.date#m-graphics.sprite.setBounds).

Example: Overriding the sprite draw method

```
-- You can copy and paste this example directly as your main.lua file to see it in action
import "CoreLibs/graphics"
import "CoreLibs/sprites"

local mySprite = playdate.graphics.sprite.new()
mySprite:moveTo(200, 120)
-- You MUST set a size first for anything to show up (either directly or by setting an image)
mySprite:setSize(30, 30)
mySprite:add()

-- The x, y, width, and height arguments refer to the dirty rect being updated, NOT the sprite dimensions
function mySprite:draw(x, y, width, height)
    -- Custom draw methods gives you more flexibility over what's drawn, but with the added benefits of sprites

    -- Here we're just modulating the circle radius over time
    local spriteWidth, spriteHeight = self:getSize()
    if not self.radius or self.radius > spriteWidth then
        self.radius = 0
    end
    self.radius += 1

    -- Drawing coordinates are relative to the sprite (e.g. (0, 0) is the top left of the sprite)
    playdate.graphics.fillCircleAtPoint(spriteWidth / 2, spriteHeight / 2, self.radius)
end

function playdate.update()
    -- Your custom draw method gets called here, but only if the sprite is dirty
    playdate.graphics.sprite.update()

    -- You might need to manually mark it dirty
    mySprite:markDirty()
end
```

[Link to this](http://sdk.play.date/inside-playdate/#c-graphics.sprite.update "Link to this")

playdate.graphics.sprite:update()

Called by [playdate.graphics.sprite.update()](http://sdk.play.date#f-graphics.sprite.update) (note the syntactic difference between the period and the colon) before sprites are drawn. Implementing `:update()` gives you the opportunity to perform some code upon every frame.

|     |     |
| --- | --- |
| Caution | Be careful not confuse `sprite:update()` with [`sprite.update()`](http://sdk.play.date#f-graphics.sprite.update): the latter updates all sprites; the former updates just the sprite being invoked. |

Example: Overriding the sprite update method

```
local mySprite = playdate.graphics.sprite.new()
mySprite:moveTo(200, 120)
mySprite:add() -- Sprite needs to be added to get drawn and updated
-- mySprite:remove() will make it so the sprite stops getting drawn/updated

-- Option 1: override the update method using an anonymous function
mySprite.update = function(self)
    print("This gets called every frame when I'm added to the display list")
    -- Manipulate sprite using "self"
    print(self.x) -- Prints 200.0
    print(self.y) -- Prints 120.0
end

-- Option 2: override the update method using a function stored in a variable
local function mySpriteUpdate(self)
    print("This gets called every frame when I'm added to the display list")
    -- Manipulate sprite using "self"
    print(self.x) -- Prints 200.0
    print(self.y) -- Prints 120.0
end
mySprite.update = mySpriteUpdate

-- Option 3: override the update method by directly defining it
function mySprite:update()
    print("This gets called every frame when I'm added to the display list")
    -- Manipulate sprite using "self"
    print(self.x) -- Prints 200.0
    print(self.y) -- Prints 120.0
end

function playdate.update()
    -- Your custom update method gets called here every frame if the sprite has been added
    playdate.graphics.sprite.update()
end

-- VERY simplified psuedocode explanation of what's happening in sprite.update() (not real code)
local displayList = {} -- Added sprites are kept track of in a list
function playdate.graphics.sprite.update()
    -- The display list is iterated over
    for i=1, #displayList do
        local sprite = displayList[i]
        -- Checks if updates on the sprites are enabled
        if sprite:updatesEnabled() then
            -- The sprite update method is called
            sprite:update()
        end
        ...
        -- Redraw all of the dirty rects, handle collisions, etc.
    end
end
```

##### [Link to this](http://sdk.play.date/inside-playdate/\#M-sprite-collisions "Link to this") Sprite collision detection

The following functions are based on the [bump.lua collision detection library](https://github.com/kikito/bump.lua). Some things to note:

- To participate in collisions, a sprite must have its [_collideRect_](http://sdk.play.date#m-graphics.sprite.setCollideRect) set.

- Only handles axis-aligned bounding box (AABB) collisions.

- Handles tunneling — all items are treated as "bullets". The fact that we only use AABBs makes this fast.

- Centered on detection, but also offers some (minimal & basic) collision response.


Ideal for:

- Tile-based games, and games where most entities can be represented as axis-aligned rectangles.

- Games which require some physics but not a full realistic simulation, like a platformer.

- Examples of appropriate genres: top-down games (Zelda), shoot 'em ups, fighting games (Street Fighter), platformers (Super Mario).


Not a good match for:

- Games that require polygons for collision detection.

- Games that require highly realistic simulations of physics - things stacking up, rolling over slides, etc.

- Games that require very fast objects colliding realistically against each other (sprites here are moved and collided one at a time).

- Simulations where the order in which the collisions are resolved isn’t known.


###### [Link to this](http://sdk.play.date/inside-playdate/\#_basic_collision_checking "Link to this") Basic collision checking

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setCollideRect "Link to this")

playdate.graphics.sprite:setCollideRect(x, y, width, height)

playdate.graphics.sprite:setCollideRect(rect)

`setCollideRect()` marks the area of the sprite, relative to its own internal coordinate system, to be checked for collisions with other sprites' collide rects. Note that the coordinate space is relative to the top-left corner of the bounds, regardless of where the sprite’s [center/anchor](http://sdk.play.date#m-graphics.sprite.setCenter) is located.

|     |     |
| --- | --- |
| Tip | If you want to set the sprite’s collide rect to be the same size as the sprite itself, you can write `sprite:setCollideRect( 0, 0, sprite:getSize() )`. |

|     |     |
| --- | --- |
| Important | `setCollideRect()` must be invoked on a sprite in order to get it to participate in collisions. |

|     |     |
| --- | --- |
| Important | Very large sprites with very large collide rects should be avoided, as they will have a negative impact on performance and memory usage. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getCollideRect "Link to this")

playdate.graphics.sprite:getCollideRect()

Returns the sprite’s collide rect set with [`setCollideRect()`](http://sdk.play.date#m-graphics.sprite.setCollideRect). Return value is a [`playdate.geometry.rect`](http://sdk.play.date#C-geometry.rect).

|     |     |
| --- | --- |
| Important | This function return coordinates relative to the sprite itself; the sprite’s position has no bearing on these values. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getCollideBounds "Link to this")

playdate.graphics.sprite:getCollideBounds()

Returns the sprite’s collide rect as multiple values, ( _x_, _y_, _width_, _height_).

|     |     |
| --- | --- |
| Important | This function return coordinates relative to the sprite itself; the sprite’s position has no bearing on these values. |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.overlappingSprites "Link to this")

playdate.graphics.sprite:overlappingSprites()

Returns an array of sprites that have collide rects that are currently overlapping the calling sprite’s collide rect, taking the sprites' groups and collides-with masks into consideration.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.allOverlappingSprites "Link to this")

playdate.graphics.sprite.allOverlappingSprites()

Returns an array of array-style tables, each containing two sprites that have overlapping collide rects. All sprite pairs that are have overlapping collide rects (taking the sprites' group and collides-with masks into consideration) are returned.

An example of iterating over the collisions array:

```
local collisions = gfx.sprite.allOverlappingSprites()

for i = 1, #collisions do
        local collisionPair = collisions[i]
        local sprite1 = collisionPair[1]
        local sprite2 = collisionPair[2]
        -- do something with the colliding sprites
end
```

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.alphaCollision "Link to this")

playdate.graphics.sprite:alphaCollision(anotherSprite)

Returns a boolean value set to true if a pixel-by-pixel comparison of the sprite images shows that non-transparent pixels are overlapping, based on the current bounds of the sprites.

This method may be used in conjunction with the standard collision architecture. Say, if [`overlappingSprites()`](http://sdk.play.date#m-graphics.sprite.overlappingSprites) or [`moveWithCollisions()`](http://sdk.play.date#m-graphics.sprite.moveWithCollisions) report a collision of two sprite’s bounding rects, alphaCollision() could then be used to discern if a pixel-level collision occurred.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setCollisionsEnabled "Link to this")

playdate.graphics.sprite:setCollisionsEnabled(flag)

The sprite’s _collisionsEnabled_ flag (defaults to true) can be set to `false` in order to temporarily keep a sprite from colliding with any other sprite.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.collisionsEnabled "Link to this")

playdate.graphics.sprite:collisionsEnabled()

Returns the sprite’s _collisionsEnabled_ flag.

###### [Link to this](http://sdk.play.date/inside-playdate/\#_restricting_collisions "Link to this") Restricting collisions

Collisions can be restricted using one of two methods: setting **collision groups**, or setting **group masks**. Groups are in fact just a simplified API for configuring group masks; they both operate on the same underlying architecture.

###### [Link to this](http://sdk.play.date/inside-playdate/\#_collision_groups "Link to this") Collision groups

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setGroups "Link to this")

playdate.graphics.sprite:setGroups(groups)

Adds the sprite to one or more collision groups. A group is a collection of sprites that exhibit similar collision behavior. (An example: in Atari’s _Asteroids_, asteroid sprites would all be added to the same group, while the player’s spaceship might be in a different group.) Use [`setCollidesWithGroups()`](http://sdk.play.date#m-graphics.sprite.setCollidesWithGroups) to define which groups a sprite should collide with.

There are 32 groups, each defined by the integer 1 through 32. To add a sprite to only groups 1 and 3, for example, call `mySprite:setGroups({1, 3})`.

Alternatively, use [`setGroupMask()`](http://sdk.play.date#m-graphics.sprite.setGroupMask) to set group membership via a bitmask.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setCollidesWithGroups "Link to this")

playdate.graphics.sprite:setCollidesWithGroups(groups)

Pass in a group number or an array of group numbers to specify which groups this sprite can collide with. Groups are numbered 1 through 32. Use [`setGroups()`](http://sdk.play.date#m-graphics.sprite.setGroups) to specify which groups a sprite belongs to.

Alternatively, you can specify group collision behavior with a bitmask by using [`setCollidesWithGroupsMask()`](http://sdk.play.date#m-graphics.sprite.setCollidesWithGroupsMask).

###### [Link to this](http://sdk.play.date/inside-playdate/\#_group_masks "Link to this") Group masks

Sprites may be assigned to groups and define which groups they collide with as a method of filtering collisions. These groups are represented by two bitmasks on the sprites: a group bitmask, and a collides-with-groups bitmask. If sprite A’s collides-with-groups bitmask overlaps sprite B’s groups (a bitwise AND of the masks is not zero), or if no groups have been set (both masks are set to 0x00000000), a collision will happen when moving sprite A through sprite B. Convenience functions [`setGroups()`](http://sdk.play.date#m-graphics.sprite.setGroups) and [`setCollidesWithGroups()`](http://sdk.play.date#m-graphics.sprite.setCollidesWithGroups) exist to avoid the need to deal with bitmasks directly.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setGroupMask "Link to this")

playdate.graphics.sprite:setGroupMask(mask)

`setGroupMask()` sets the sprite’s group bitmask, which is 32 bits. In conjunction with the [`setCollidesWithGroupsMask()`](http://sdk.play.date#m-graphics.sprite.setCollidesWithGroupsMask) method, this controls which sprites can collide with each other.

For large group mask numbers, pass the number as a hex value, eg. `0xFFFFFFFF` to work around limitations in Lua’s integer sizes.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getGroupMask "Link to this")

playdate.graphics.sprite:getGroupMask()

`getGroupMask()` returns the integer value of the sprite’s group bitmask.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.setCollidesWithGroupsMask "Link to this")

playdate.graphics.sprite:setCollidesWithGroupsMask(mask)

Sets the sprite’s collides-with-groups bitmask, which is 32 bits. The mask specifies which other sprite groups this sprite can collide with. Sprites only collide if the moving sprite’s _collidesWithGroupsMask_ matches at least one group of a potential collision sprite (i.e. a bitwise AND (&) between the moving sprite’s _collidesWithGroupsMask_ and a potential collision sprite’s _groupMask_ != zero) or if the moving sprite’s _collidesWithGroupsMask_ and the other sprite’s _groupMask_ are both set to 0x00000000 (the default values).

For large mask numbers, pass the number as a hex value, eg. `0xFFFFFFFF` to work around limitations in Lua’s integer sizes.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.getCollidesWithGroupsMask "Link to this")

playdate.graphics.sprite:getCollidesWithGroupsMask()

Returns the integer value of the sprite’s collision bitmask.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.resetGroupMask "Link to this")

playdate.graphics.sprite:resetGroupMask()

Resets the sprite’s group mask to `0x00000000`.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.resetCollidesWithGroupsMask "Link to this")

playdate.graphics.sprite:resetCollidesWithGroupsMask()

Resets the sprite’s collides-with-groups mask to `0x00000000`.

###### [Link to this](http://sdk.play.date/inside-playdate/\#_advanced_collisions "Link to this") Advanced Collisions

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.moveWithCollisions "Link to this")

playdate.graphics.sprite:moveWithCollisions(goalX, goalY)

playdate.graphics.sprite:moveWithCollisions(goalPoint)

Moves the sprite towards _goalX_, _goalY_ or _goalPoint_ taking collisions into account, which means the sprite’s final position may not be the same as _goalX_, _goalY_ or _goalPoint_.

Returns _actualX_, _actualY_, _collisions_, _length_.

|     |     |
| --- | --- |
| _actualX_, _actualY_ | the final position of the sprite. If no collisions occurred, this will be the same as _goalX_, _goalY_. |
| _collisions_ | an array of userdata objects containing information about all collisions that occurred. Each item in the array contains values for the following indices:<br>\- _sprite_: The sprite being moved.<br>\- _other_: The sprite colliding with the sprite being moved.<br>\- _type_: The result of [_collisionResponse_](http://sdk.play.date#c-graphics.sprite.collisionResponse).<br>\- _overlaps_: Boolean. True if the sprite was overlapping _other_ when the collision started. False if it didn’t overlap but tunneled through _other_.<br>\- _ti_: A number between 0 and 1 indicating how far along the movement to the goal the collision occurred.<br>\- _move_: [playdate.geometry.vector2D](http://sdk.play.date#C-geometry.vector2D). The difference between the original coordinates and the actual ones when the collision happened.<br>\- _normal_: [playdate.geometry.vector2D](http://sdk.play.date#C-geometry.vector2D). The collision normal; usually -1, 0, or 1 in _x_ and _y_. Use this value to determine things like if your character is touching the ground.<br>\- _touch_: [playdate.geometry.point](http://sdk.play.date#C-geometry.point). The coordinates where the sprite started touching _other_.<br>\- _spriteRect_: [playdate.geometry.rect](http://sdk.play.date#C-geometry.rect). The rectangle the sprite occupied when the touch happened.<br>\- _otherRect_: [playdate.geometry.rect](http://sdk.play.date#C-geometry.rect). The rectangle `other` occupied when the touch happened.<br>If the collision type was _playdate.graphics.sprite.kCollisionTypeBounce_ the table also contains _bounce_, a [playdate.geometry.point](http://sdk.play.date#C-geometry.point) indicating the coordinates to which the sprite attempted to bounce (could be different than _actualX_, _actualY_ if further collisions occurred).<br>If the collision type was _playdate.graphics.sprite.kCollisionTypeSlide_ the table also contains _slide_, a [playdate.geometry.point](http://sdk.play.date#C-geometry.point) indicating the coordinates to which the sprite attempted to slide. |
| _length_ | the length of the collisions array, equal to _#collisions_ |

Note that the collision info items are only valid until the next call of _moveWithCollisions_ or _checkCollisions_. To save collision information for later, the data should be copied out of the collision info userdata object.

See also [`checkCollisions()`](http://sdk.play.date#m-graphics.sprite.checkCollisions) to check for collisions without actually moving the sprite.

Example: Using moveWithCollisions for a simple player collision example

```
-- You can copy and paste this example directly as your main.lua file to see it in action
import "CoreLibs/graphics"
import "CoreLibs/sprites"

-- Creating a tags object, to keep track of tags more easily
TAGS = {
    player = 1,
    obstacle = 2,
    coin = 3,
    powerUp = 4
}

-- Creating a player sprite we can move around and collide things with
local playerImage = playdate.graphics.image.new(20, 20)
playdate.graphics.pushContext(playerImage)
    playdate.graphics.fillCircleInRect(0, 0, playerImage:getSize())
playdate.graphics.popContext()
local playerSprite = playdate.graphics.sprite.new(playerImage)
-- Setting a tag on the player, so we can check the tag to see if we're colliding against the player
playerSprite:setTag(TAGS.player)
playerSprite:moveTo(200, 120)
-- Remember to set a collision rect, or this all doesn't work!
playerSprite:setCollideRect(0, 0, playerSprite:getSize())
playerSprite:add()

-- Creating an obstacle sprite we can collide against
local obstacleImage = playdate.graphics.image.new(20, 20, playdate.graphics.kColorBlack)
local obstacleSprite = playdate.graphics.sprite.new(obstacleImage)
-- Setting a tag for the obstacle as well
obstacleSprite:setTag(TAGS.obstacle)
obstacleSprite:moveTo(300, 120)
-- Can't forget this!
obstacleSprite:setCollideRect(0, 0, obstacleSprite:getSize())
obstacleSprite:add()

function playdate.update()
    playdate.graphics.sprite.update()

    -- Some simple movement code for the sake of demonstration
    local moveSpeed = 3
    local goalX, goalY = playerSprite.x, playerSprite.y
    if playdate.buttonIsPressed(playdate.kButtonUp) then
        goalY -= moveSpeed
    elseif playdate.buttonIsPressed(playdate.kButtonDown) then
        goalY += moveSpeed
    elseif playdate.buttonIsPressed(playdate.kButtonLeft) then
        goalX -= moveSpeed
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        goalX += moveSpeed
    end

    -- Remember to use :moveWithCollisions(), and not :moveTo() or :moveBy(), or collisions won't happen!
    -- To do a "moveBy" operation, sprite:moveBy(5, 5) == sprite:moveWithCollisions(sprite.x + 5, sprite.y + 5)
    local actualX, actualY, collisions, numberOfCollisions = playerSprite:moveWithCollisions(goalX, goalY)

    -- If we get into this loop, there was a collision
    for i=1, numberOfCollisions do
        -- This is getting data about one of things we're currently colliding with. Since we could
        -- be colliding with multiple things at once, we have to handle each collision individually
        local collision = collisions[i]

        -- Always prints 'true', as the sprite property is the sprite being moved (in this case, the player)
        print(collision.sprite == playerSprite)
        -- Also prints 'true', as we set the tag on the player sprite to the player tag
        print(collision.sprite:getTag() == TAGS.player)

        -- This gets the actual sprite object we're colliding with
        local collidedSprite = collision.other
        local collisionTag = collidedSprite:getTag()
        -- Since we set a tag on the obstacle, we can check if we're colliding with that
        if collisionTag == TAGS.obstacle then
            print("Collided with an obstacle!")

            -- We can use the collision normal to check which side we collided with
            local collisionNormal = collision.normal
            if collisionNormal.x == -1 then
                print("Touched left side!")
            elseif collisionNormal.x == 1 then
                print("Touched right side!")
            end

            if collisionNormal.y == -1 then
                print("Touched top!")
            elseif collisionNormal.y == 1 then
                print("Touched bottom!")
            end
        -- Handle some other collisions, like collecting a coin or a power up
        elseif collisionTag == TAGS.coin then
            print("Coin collected!")
        elseif collisionTag == TAGS.powerUp then
            print("Powered up!")
        end
    end
end
```

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.sprite.checkCollisions "Link to this")

playdate.graphics.sprite:checkCollisions(x, y)

playdate.graphics.sprite:checkCollisions(point)

Returns the same values as [`moveWithCollisions()`](http://sdk.play.date#m-graphics.sprite.moveWithCollisions) but does not actually move the sprite.

[Link to this](http://sdk.play.date/inside-playdate/#c-graphics.sprite.collisionResponse "Link to this")

playdate.graphics.sprite:collisionResponse(other)

A callback that can be defined on a sprite to control the type of collision response that should happen when a collision with _other_ occurs. This callback should return one of the following four values:

- _playdate.graphics.sprite.kCollisionTypeSlide_: Use for collisions that should slide over other objects, like Super Mario does over a platform or the ground.

- _playdate.graphics.sprite.kCollisionTypeFreeze_: Use for collisions where the sprite should stop moving as soon as it collides with _other_, such as an arrow hitting a wall.

- _playdate.graphics.sprite.kCollisionTypeOverlap_: Use for collisions in which you want to know about the collision but it should not impact the movement of the sprite, such as when collecting a coin.

- _playdate.graphics.sprite.kCollisionTypeBounce_: Use when the sprite should move away from _other_, like the ball in Pong or Arkanoid.


The strings "slide", "freeze", "overlap", and "bounce" can be used instead of the constants.

Feel free to return different values based on the value of _other_. For example, if _other_ is a wall sprite, you may want to return "slide" or "bounce", but if it’s a coin you might return "overlap".

If the callback is not present, or returns nil, _kCollisionTypeFreeze_ is used.

|     |     |
| --- | --- |
| Tip | Instead of defining a callback, the collisionResponse property of a sprite can be set directly to one of the four collision response types. This will be faster, as the lua function will not need to be called, but does not allow for dynamic behavior. |

This method should not attempt to modify the sprites in any way. While it might be tempting to deal with collisions here, doing so will have unexpected and undesirable results. Instead, this function should return one of the collision response values as quickly as possible. If sprites need to be modified as the result of a collision, do so elsewhere, such as by inspecting the list of collisions returned by [`moveWithCollisions()`](http://sdk.play.date#m-graphics.sprite.moveWithCollisions).

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.querySpriteInfoAlongLine "Link to this")

playdate.graphics.sprite.querySpriteInfoAlongLine(x1, y1, x2, y2)

playdate.graphics.sprite.querySpriteInfoAlongLine( [lineSegment](http://sdk.play.date#C-geometry.lineSegment))

Similar to _querySpritesAlongLine()_, but instead of sprites returns an array of _collisionInfo_ tables containing information about sprites intersecting the line segment, and _len_, which is the number of collisions found. If you don’t need this information, use _querySpritesAlongLine()_ as it will be faster.

Each _collisionInfo_ table contains:

- _sprite_: the sprite being intersected by the segment.

- _entryPoint_: a [`point`](http://sdk.play.date#C-geometry.point) representing the coordinates of the first intersection between `sprite` and the line segment.

- _exitPoint_: a [`point`](http://sdk.play.date#C-geometry.point) representing the coordinates of the second intersection between `sprite` and the line segment.

- _ti1_ & _ti2_: numbers between 0 and 1 which indicate how far from the starting point of the line segment the collision happened; t1 for the entry point, t2 for the exit point. This can be useful for things like having a laser cause more damage if the impact is close.


##### [Link to this](http://sdk.play.date/inside-playdate/\#_sprites_in_tilemap_based_games "Link to this") Sprites in tilemap-based games

For tile-based games, the built-in tilemap library has a convenience function called [getCollisionRects()](http://sdk.play.date#m-graphics.tilemap.getCollisionRects), which will generate from the tilemap an array of rectangles suitable for use with the collision system to define walls and other impassable regions.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.addEmptyCollisionSprite "Link to this")

playdate.graphics.sprite.addEmptyCollisionSprite(r)

playdate.graphics.sprite.addEmptyCollisionSprite(x, y, w, h)

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/sprites_ to use this function. |

This convenience function adds an invisible sprite defined by the rectangle _x_, _y_, _w_, _h_ (or the [playdate.geometry.rect](http://sdk.play.date#C-geometry.rect) _r_) for the purpose of triggering collisions. This is useful for making areas impassable, triggering an event when a sprite enters a certain area, and so on.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.sprite.addWallSprites "Link to this")

playdate.graphics.sprite.addWallSprites(tilemap, emptyIDs, \[xOffset, yOffset\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/sprites_ to use this function. |

This convenience function automatically adds empty collision sprites necessary to restrict movement within a tilemap.

_tilemap_ is a [playdate.graphics.tilemap](http://sdk.play.date#C-graphics.tilemap).

_emptyIDs_ is an array of tile IDs that should be considered "passable" — in other words, not walls. Tiles with default IDs of 0 are treated as passable by default, so you do not need to include 0 in the array.

_xOffset, yOffset_ optionally indicate the distance the new sprites should be offset from (0,0).

Returns an array-style table of the newly created sprites.

Calling this function is effectively a shortcut for calling [playdate.graphics.tilemap:getCollisionRects()](http://sdk.play.date#m-graphics.tilemap.getCollisionRects) and passing the resulting rects to [addEmptyCollisionSprite()](http://sdk.play.date#f-graphics.sprite.addEmptyCollisionSprite).

#### [Link to this](http://sdk.play.date/inside-playdate/\#_text "Link to this") Text

##### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.font "Link to this") Fonts

Playdate fonts are [playdate.graphics.font](http://sdk.play.date#C-graphics.font) objects, loaded into Lua with the [playdate.graphics.font.new(path)](http://sdk.play.date#f-graphics.font.new) function and drawn on screen using [playdate.graphics.drawText(text, x, y)](http://sdk.play.date#f-graphics.drawText).

The compiler can create a font from a standalone .fnt file with embedded image data or by combining a dependent .fnt file with a related image table. For example, if a dependent .fnt file is named awesomefont.fnt then the related image table would be named awesomefont-table-9-12.png

Standalone .fnt files can be created with the [_Playdate Caps_](https://play.date/caps/) web app from scratch or from a dependent .fnt file and image table pair.

At its simplest, a dependent .fnt file contains one line per glyph. Each line contains the glyph (the space character is indicted with the text "space"), in the order the glyph appears in the image table, and the width of the glyph, separated by any amount of whitespace. Unicode _U+xxxx_ format is supported for glyph names.

Sample .fnt file excerpt

```
space	6
!		2
"		4
#		7
```

Blank lines are ignored. Comments begin with two dashes.

Sample .fnt file excerpt

```
$		6
%		8
-- this comment will be ignored, as will any blank lines
&		7
```

An optional, default tracking value can be specified on its own line like so:

Sample .fnt file excerpt

```
tracking = 2
```

The tracking value is the number of pixels of whitespace between each character drawn in a string.

Kerning pairs are supported, one line per pair. Each line contains the two character pair, and the offset, separated by any amount of whitespace.

Sample .fnt file excerpt

```
To		-2
ll		3
bU+20	-1
```

A standalone .fnt file must contain these additional properties to compile correctly. (While a standalone .fnt file can be authored manually, most will be created with _Playdate Caps_. This informataion is included here for thoroughness.)

Embedding a font’s pixel data requires 4 additional properties: the string length of the base64-encoded image table data as `datalen`, a base64-encoded image table as `data`, and the pixel dimensions of each uniform cell in the image table as `width`, and `height`.

Sample standalone .fnt file excerpt

```
datalen=8984
data=iVBO...YII=
width=8
height=12
```

_Playdate Caps_ will also embed some metrics used for authoring as a JSON object in a comment.

Sample standalone .fnt file excerpt

```
--metrics={"baseline":17,"xHeight":6,"capHeight":2}
```

###### [Link to this](http://sdk.play.date/inside-playdate/\#_supported_characters "Link to this") Supported characters

Playdate supports all code points in the first four Unicode planes, up to U+3FFFF.

If a replacement character is specified it will be drawn in place of any missing characters in your font. If it is not, characters missing from the font will be drawn using the system font, if available.

###### [Link to this](http://sdk.play.date/inside-playdate/\#_variants "Link to this") Variants

In order to support formatting and localization, Playdate allows you to set up to three font files as variants: normal, bold, and italic.

###### [Link to this](http://sdk.play.date/inside-playdate/\#_font_class_functions "Link to this") Font class functions

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.font.new "Link to this")

playdate.graphics.font.new(path)

Returns a [playdate.graphics.font](http://sdk.play.date#C-graphics.font) object from the data at _path_. If there is no file at _path_, the function returns nil.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.font.newFamily "Link to this")

playdate.graphics.font.newFamily(fontPaths)

Returns a font family table from the font files specified in _fontPaths_. _fontPaths_ should be a table with the following format:

```
local fontPaths = {
 [playdate.graphics.font.kVariantNormal] = "path/to/normalFont",
    [playdate.graphics.font.kVariantBold] = "path/to/boldFont",
    [playdate.graphics.font.kVariantItalic] = "path/to/italicFont"
}
```

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setFont "Link to this")

playdate.graphics.setFont(font, \[variant\])

Sets the current font, a [playdate.graphics.font](http://sdk.play.date#C-graphics.font).

_variant_ should be one of the strings "normal", "bold", or "italic", or one of the constants:

- _playdate.graphics.font.kVariantNormal_

- _playdate.graphics.font.kVariantBold_

- _playdate.graphics.font.kVariantItalic_


If no variant is specified, _kFontVariantNormal_ is used.

Equivalent to [`playdate->graphics->setFont()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setFont) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getFont "Link to this")

playdate.graphics.getFont(\[variant\])

Returns the current font, a [playdate.graphics.font](http://sdk.play.date#C-graphics.font).

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setFontFamily "Link to this")

playdate.graphics.setFontFamily(fontFamily)

Sets multiple font variants at once. `fontFamily` should be a table using the following format:

```
local fontFamily = {
 [playdate.graphics.font.kVariantNormal] = normal_font,
    [playdate.graphics.font.kVariantBold] = bold_font,
    [playdate.graphics.font.kVariantItalic] = italic_font
}
```

All fonts and font variants need not be present in the table.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.setFontTracking "Link to this")

playdate.graphics.setFontTracking(pixels)

Sets the global font tracking (spacing between letters) in pixels. This value is added to the font’s own tracking value as specified in its .fnt file.

See [playdate.graphics.font:setTracking](http://sdk.play.date#m-graphics.font.setTracking) to adjust tracking on a specific font.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getFontTracking "Link to this")

playdate.graphics.getFontTracking()

Gets the global font tracking (spacing between letters) in pixels.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getSystemFont "Link to this")

playdate.graphics.getSystemFont(\[variant\])

Like [getFont()](http://sdk.play.date#f-graphics.getFont) but returns the system font rather than the currently set font.

_variant_ should be one of the strings "normal", "bold", or "italic", or one of the constants:

- _playdate.graphics.font.kVariantNormal_

- _playdate.graphics.font.kVariantBold_

- _playdate.graphics.font.kVariantItalic_


###### [Link to this](http://sdk.play.date/inside-playdate/\#_font_instance_functions "Link to this") Font instance functions

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.font.drawText "Link to this")

playdate.graphics.font:drawText(text, x, y, \[width, height\], \[leadingAdjustment\], \[wrapMode\], \[alignment\])

playdate.graphics.font:drawText(text, rect, \[leadingAdjustment\], \[wrapMode\], \[alignment\])

Draws a string at the specified _x, y_ coordinate using this particular font instance. (Compare to [playdate.graphics.drawText(text, x, y)](http://sdk.play.date#f-graphics.drawText), which draws the string with whatever the "current font" is, as defined by [playdate.graphics.setFont(font)](http://sdk.play.date#f-graphics.setFont)).

If _width_ and _height_ are specified, drawing is constrained to the rectangle `(x,y,width,height)`, using the given `wrapMode` and `alignment` if provided. Alternatively, a [`playdate.geometry.rect`](http://sdk.play.date#C-geometry.rect) object can be passed instead of `x,y,width,height`. Valid values for _wrapMode_ are

- _playdate.graphics.kWrapClip_

- _playdate.graphics.kWrapCharacter_

- _playdate.graphics.kWrapWord_


and values for _alignment_ are

- _playdate.graphics.kAlignLeft_

- _playdate.graphics.kAlignCenter_

- _playdate.graphics.kAlignRight_


The default wrap mode is `playdate.graphics.kWrapWord` and the default alignment is `playdate.graphics.kAlignLeft`.

The optional _leadingAdjustment_ may be used to modify the spacing between lines of text.

The function returns two numbers indicating the width and height of the drawn text.

|     |     |
| --- | --- |
| Note | `font:drawText()` does not support inline styles like bold and italics. Instead use [playdate.graphics.drawText()](http://sdk.play.date#f-graphics.drawText). |

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.font.drawTextAligned "Link to this")

playdate.graphics.font:drawTextAligned(text, x, y, alignment, \[leadingAdjustment\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use this function. |

Draws the string _text_ aligned to the left, right, or centered on the _x_ coordinate. Pass one of _kTextAlignment.left_, _kTextAlignment.center_, _kTextAlignment.right_ for the _alignment_ parameter. (Compare to [playdate.graphics.drawTextAligned(text, x, y, alignment)](http://sdk.play.date#f-graphics.drawTextAligned), which draws the string with the "current font", as defined by [playdate.graphics.setFont(font)](http://sdk.play.date#f-graphics.setFont)).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.font.getHeight "Link to this")

playdate.graphics.font:getHeight()

Returns the pixel height of this font.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.font.getTextWidth "Link to this")

playdate.graphics.font:getTextWidth(text)

Returns the pixel width of the text when rendered with this font.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.font.setTracking "Link to this")

playdate.graphics.font:setTracking(pixels)

Sets the tracking of this font (spacing between letters), in pixels.

Equivalent to [`playdate->graphics->setTextTracking()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setTextTracking) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.font.getTracking "Link to this")

playdate.graphics.font:getTracking()

Returns the tracking of this font (spacing between letters), in pixels.

Equivalent to [`playdate->graphics->getTextTracking()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.getTextTracking) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.font.setLeading "Link to this")

playdate.graphics.font:setLeading(pixels)

Sets the leading (spacing between lines) of this font, in pixels.

Equivalent to [`playdate->graphics->setTextLeading()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.setTextLeading) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.font.getLeading "Link to this")

playdate.graphics.font:getLeading()

Returns the leading (spacing between lines) of this font, in pixels.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.font.getGlyph "Link to this")

playdate.graphics.font:getGlyph(character)

Returns the [`playdate.graphics.image`](http://sdk.play.date#C-graphics.image) containing the requested glyph. _character_ can either be a string or a unicode codepoint number.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_drawing_text "Link to this") Drawing Text

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawText "Link to this")

playdate.graphics.drawText(text, x, y, \[width, height\], \[fontFamily\], \[leadingAdjustment\], \[wrapMode\], \[alignment\])

playdate.graphics.drawText(text, rect, \[fontFamily\], \[leadingAdjustment\], \[wrapMode\], \[alignment\])

Draws the text using the current font and font advance at location ( _x_, _y_). If _width_ and _height_ are specified, drawing is constrained to the rectangle `(x,y,width,height)`, using the given _wrapMode_ and _alignment_, if provided. Alternatively, a [`playdate.geometry.rect`](http://sdk.play.date#C-geometry.rect) object can be passed instead of `x,y,width,height`. Valid values for _wrapMode_ are

- _playdate.graphics.kWrapClip_

- _playdate.graphics.kWrapCharacter_

- _playdate.graphics.kWrapWord_


and values for _alignment_ are

- _playdate.graphics.kAlignLeft_

- _playdate.graphics.kAlignCenter_

- _playdate.graphics.kAlignRight_


The default wrap mode is `playdate.graphics.kWrapWord` and the default alignment is `playdate.graphics.kAlignLeft`.

If _fontFamily_ is provided, the text is draw using the given fonts instead of the currently set font. _fontFamily_ should be a table of fonts using keys as specified in [setFontFamily(fontFamily)](http://sdk.play.date#f-graphics.setFontFamily).

The optional _leadingAdjustment_ may be used to modify the spacing between lines of text. Pass nil to use the default leading for the font.

Returns two numbers indicating the width and height of the drawn text.

**Styling text**

To draw bold text, surround the bold portion of text with asterisks. To draw italic text, surround the italic portion of text with underscores. For example:

```
playdate.graphics.drawText("normal *bold* _italic_", x, y)
```

which will output: "normal **bold** _italic_". Bold and italic font variations must be set using [setFont()](http://sdk.play.date#f-graphics.setFont) with the appropriate variant argument, otherwise the default Playdate fonts will be used.

**Escaping styling characters**

To draw an asterisk or underscore, use a double-asterisk or double-underscore. Styles may not be nested, but double-characters can be used inside of a styled portion of text.

For a complete set of characters allowed in _text_, see [playdate.graphics.font](http://sdk.play.date#C-graphics.font). In addition, the newline character `\n` is allowed and works as expected.

**Avoiding styling**

Use [playdate.graphics.font:drawText()](http://sdk.play.date#m-graphics.font.drawText), which doesn’t support formatted text.

**Inverting text color**

To draw white-on-black text (assuming the font you are using is defined in the standard black-on-transparent manner), first call [playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeFillWhite)](http://sdk.play.date#f-graphics.setImageDrawMode), followed by the appropriate drawText() call. setImageDrawMode() affects how text is rendered because characters are technically images.

Equivalent to [`playdate->graphics->drawText()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-graphics.drawText) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawLocalizedText "Link to this")

playdate.graphics.drawLocalizedText(key, x, y, \[width, height\], \[language\], \[leadingAdjustment\], \[wrapMode\], \[alignment\])

playdate.graphics.drawLocalizedText(key, rect, \[language\], \[leadingAdjustment\])

Draws the text found by doing a lookup of _key_ in the .strings file corresponding to the current system language, or _language_, if specified.

The optional _language_ argument can be one of the strings "en", "jp", or one of the constants:

- _playdate.graphics.font.kLanguageEnglish_

- _playdate.graphics.font.kLanguageJapanese_


Other arguments work the same as in [`drawText()`](http://sdk.play.date#f-graphics.drawText).

For more information about localization and strings files, see the [Localization](http://sdk.play.date#localization) section.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getLocalizedText "Link to this")

playdate.graphics.getLocalizedText(key, \[language\])

Returns a string found by doing a lookup of _key_ in the .strings file corresponding to the current system language, or _language_, if specified.

The optional _language_ argument can be one of the strings "en", "jp", or one of the constants:

- _playdate.graphics.font.kLanguageEnglish_

- _playdate.graphics.font.kLanguageJapanese_


For more information about localization and strings files, see the [Localization](http://sdk.play.date#localization) section.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getTextSize "Link to this")

playdate.graphics.getTextSize(str, \[fontFamily, \[leadingAdjustment\]\])

Returns multiple values _(width, height)_ giving the dimensions required to draw the text _str_ using [drawText()](http://sdk.play.date#f-graphics.drawText). Newline characters ( `\n`) are respected.

_fontFamily_ should be a table of fonts using keys as specified in [setFontFamily(fontFamily)](http://sdk.play.date#f-graphics.setFontFamily). If provided, fonts from _fontFamily_ will be used for calculating the size of _str_ instead of the currently set font.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawTextAligned "Link to this")

playdate.graphics.drawTextAligned(text, x, y, alignment, \[leadingAdjustment\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use this function. |

Draws the string _text_ aligned to the left, right, or centered on the _x_ coordinate. Pass one of _kTextAlignment.left_, _kTextAlignment.center_, _kTextAlignment.right_ for the _alignment_ parameter.

For text formatting options, see [drawText()](http://sdk.play.date#f-graphics.drawText)

To draw unstyled text using a single font, see [playdate.graphics.font:drawTextAligned()](http://sdk.play.date#m-graphics.font.drawTextAligned)

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawTextInRect "Link to this")

playdate.graphics.drawTextInRect(text, x, y, width, height, \[leadingAdjustment, \[truncationString, \[alignment, \[font\]\]\]\])

playdate.graphics.drawTextInRect(text, rect, \[leadingAdjustment, \[truncationString, \[alignment, \[font\]\]\]\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use these functions. |

Draws the text using the current font and font advance into the rect defined by ( `x`, `y`, `width`, `height`) (or `rect`).

If `truncationString` is provided and the text cannot fit in the rect, `truncationString` will be appended to the last line.

`alignment`, if provided, should be one of one of `kTextAlignment.left`, `kTextAlignment.center`, `kTextAlignment.right`. Pass `nil` for `leadingAdjustment` and `truncationString` if those parameters are not required.

`font`, if provided, will cause the text to be drawn unstyled using [font:drawText()](http://sdk.play.date#m-graphics.font.drawText) rather than [playdate.graphics.drawText()](http://sdk.play.date#f-graphics.drawText) using the currently-set system fonts.

For text formatting options, see [drawText()](http://sdk.play.date#f-graphics.drawText)

Returns `width`, `height`, `textWasTruncated`

`width` and `height` indicate the size in pixels of the drawn text. These values may be smaller than the width and height specified when calling the function.

`textWasTruncated` indicates if the text was truncated to fit within the specified rect.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawLocalizedTextAligned "Link to this")

playdate.graphics.drawLocalizedTextAligned(text, x, y, alignment, \[language, \[leadingAdjustment\]\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use this function. |

Same as [drawTextAligned()](http://sdk.play.date#f-graphics.drawTextAligned) except localized text is drawn.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.drawLocalizedTextInRect "Link to this")

playdate.graphics.drawLocalizedTextInRect(text, x, y, width, height, \[leadingAdjustment, \[truncationString, \[alignment, \[font, \[language\]\]\]\]\])

playdate.graphics.drawLocalizedTextInRect(text, rect, \[leadingAdjustment, \[truncationString, \[alignment, \[font, \[language\]\]\]\]\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use these functions. |

Same as [drawTextInRect()](http://sdk.play.date#f-graphics.drawTextInRect) except localized text is drawn.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.getTextSizeForMaxWidth "Link to this")

playdate.graphics.getTextSizeForMaxWidth(text, maxWidth, \[leadingAdjustment, \[font\]\]\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use this function. |

Returns `width`, `height` which indicate the minimum size required for `text` to be drawn using [drawTextInRect()](http://sdk.play.date#f-graphics.drawTextInRect). The `width` returned will be less than or equal to `maxWidth`.

`font`, if provided, will cause the text size to be calculated without bold or italic styling using the specified font.

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.imageWithText "Link to this")

playdate.graphics.imageWithText(text, maxWidth, maxHeight, \[backgroundColor, \[leadingAdjustment, \[truncationString, \[alignment, \[font\]\]\]\]\])

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/graphics_ to use this function. |

Generates an image containing `text`. This is useful if you need to redraw the same text frequently.

`maxWidth` and `maxHeight` specify the maximum size of the returned image.

`backgroundColor`, if specified, will cause the image’s background to be one of _playdate.graphics.kColorWhite_, _playdate.graphics.kColorBlack_, or _playdate.graphics.kColorClear_.

`font`, if provided, will cause the text to be drawn without bold or italic styling using the specified font.

The remaining arguments are the same as those in [drawTextInRect()](http://sdk.play.date#f-graphics.drawTextInRect).

Returns `image`, `textWasTruncated`

`image` is a newly-created image containing the specified text, or nil if an image could not be created. The image’s dimensions may be smaller than `maxWidth`, `maxHeight`.

`textWasTruncated` indicates if the text was truncated to fit within the specified width and height.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-graphics.video "Link to this") Video

The video player renders frames from a pdv file into an image or directly to the screen. Note that the renderer expects to have ownership of the data in its drawing context, whether it’s the screen or a separate image. Drawing over the video frames in the render context can cause the image to become garbled. If you want to use drawing functions on top of the video, create a context image for the video to render to (calling video:getContext() will create the image), call video:renderFrame(), then draw the context image to the screen, then draw on top of that. The pdv file does not (currently) contain audio, so typically you’d play the audio in a fileplayer or sampleplayer and use the current audio offset to determine which video frame to display.

A minimal video player:

```
local disp = playdate.display
local gfx = playdate.graphics
local snd = playdate.sound

disp.setRefreshRate(0)

local video = gfx.video.new('movie')
video:useScreenContext()
video:renderFrame(0)

local lastframe = 0

local audio, loaderr = snd.sampleplayer.new('movie')

if audio ~= nil then
        audio:play(0)
else
        print(loaderr)
end

function playdate.update()

        local frame = math.floor(audio:getOffset() * video:getFrameRate())

        if frame ~= lastframe then
                video:renderFrame(frame)
                lastframe = frame
        end
end
```

[Link to this](http://sdk.play.date/inside-playdate/#f-graphics.video.new "Link to this")

playdate.graphics.video.new(path)

Returns a [playdate.graphics.video](http://sdk.play.date#C-graphics.video) object from the pdv file at _path_. If the file at _path_ can’t be opened, the function returns nil.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.video.getSize "Link to this")

playdate.graphics.video:getSize()

Returns the width and height of the video as multiple vlaues ( _width_, _height_).

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.video.getFrameCount "Link to this")

playdate.graphics.video:getFrameCount()

Returns the number of frames in the video.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.video.getFrameRate "Link to this")

playdate.graphics.video:getFrameRate()

Returns the number of frames per second of the video source. This number is simply for record-keeping, it is not used internally—​the game code is responsible for figuring out which frame to show when.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.video.setContext "Link to this")

playdate.graphics.video:setContext(image)

Sets the given image to the video render context. Future `video:renderFrame()` calls will draw into this image.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.video.getContext "Link to this")

playdate.graphics.video:getContext()

Returns the image into which the video will be rendered, creating it if needed.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.video.useScreenContext "Link to this")

playdate.graphics.video:useScreenContext()

Sets the display framebuffer as the video’s render context.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.video.renderFrame "Link to this")

playdate.graphics.video:renderFrame(number)

Draws the given frame into the video’s render context.

[Link to this](http://sdk.play.date/inside-playdate/#m-graphics.video.getCurrentFrame "Link to this")

playdate.graphics.video:getCurrentFrame()

Returns the frame number of the currently displayed frame.

### [[7.21 JSON]]

### [[7.22 Keyboard]]
### [Link to this](http://sdk.play.date/inside-playdate/\#M-math "Link to this") 7.23. Math

[Link to this](http://sdk.play.date/inside-playdate/#f-math.lerp "Link to this")

playdate.math.lerp(min, max, t)

Returns a number that is the linear interpolation between _min_ and _max_ based on _t_, where _t = 0.0_ will return _min_ and _t = 1.0_ will return _max_.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/math_ to use this function. |

### [Link to this](http://sdk.play.date/inside-playdate/\#M-network "Link to this") 7.24. Networking

Playdate OS 2.7 adds support for both HTTP and TCP networking. Up to four simultaneous connections are possible.

[Link to this](http://sdk.play.date/inside-playdate/#f-network.setEnabled "Link to this")

playdate.network.setEnabled(flag, function)

Playdate will connect to the configured access point automatically as needed and turn off the wifi radio after a 30 second idle timeout. This function allows a game to start connecting to the access point sooner, since that can take upwards of 10 seconds, or turn off wifi as soon as it’s no longer needed instead of waiting 30 seconds. If `flag` is true, a callback function can be provided to check for an error connecting to the access point; the argument passed to the callback is a string describing the error, or nil if no error occurred.

[Link to this](http://sdk.play.date/inside-playdate/#f-network.getStatus "Link to this")

playdate.network.getStatus()

Returns one of the constants:

- _playdate.network.kStatusNotConnected_ : Not connected to an AP

- _playdate.network.kStatusConnected_ : Device is connected to an AP

- _playdate.network.kStatusNotAvailable_ : No configured AP is available


#### [Link to this](http://sdk.play.date/inside-playdate/\#C-network.http "Link to this") HTTP

[Link to this](http://sdk.play.date/inside-playdate/#f-network.http.new "Link to this")

playdate.network.http.new(server, \[port\], \[usessl\], \[reason\])

Returns a `playdate.network.http` object for connecting to the given server. The default port is 443 if `usessl` is true, otherwise 80; the default value for `usessl` is false. If the user has not yet given permission for the device to connect to the server, the game is paused while the system asks the user to allow or deny network access for the provided `reason`, if one is given. Since the system uses a coroutine `yield()` to show the dialog to request access (if not already given), it cannot be called at load time or from an input handler or other system callback.

[Link to this](http://sdk.play.date/inside-playdate/#f-network.http.requestAccess "Link to this")

playdate.network.http.requestAccess(\[server\], \[port\], \[usessl\], \[reason\])

`playdate.network.http.new()` will automatically request access if needed (and note that `new()` only creates an object for connecting, doesn’t open the connection until `get()` or `post()` is called) but if you want to present the access dialog ahead of time you can use this function. Notably, this lets you request access to all HTTP servers by leaving the `server` field empty, or all subdomains of a domain by passing in the parent. Note that this function uses a coroutine `yield()` to pause the runtime while the permission dialog is up, so it can’t be called immediately at startup, must be called from a `playdate.update()` context

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.close "Link to this")

playdate.network.http:close()

Closes the HTTP connection. The connection may be used again for another request.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.setKeepAlive "Link to this")

playdate.network.http:setKeepAlive(flag)

If `flag` is true, this causes the HTTP request to include a _Connection: keep-alive_ header.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.setByteRange "Link to this")

playdate.network.http:setByteRange(from, to)

Adds a `Range: bytes` header to the HTTP request.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.setConnectTimeout "Link to this")

playdate.network.http:setConnectTimeout(seconds)

Sets the length of time (in seconds) to wait for the connection to the server to be made.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.get "Link to this")

playdate.network.http:get(path, \[headers\])

Opens the connection to the server if it’s not already open (e.g. from a previous request with the given path and additional _headers_ if specified. The _headers_ argument can either be a string containing all of the headers to send (with newlines between individual headers), an array of strings, or a table of key/value pairs.

If the request is successfully queued, the function returns `true`. On error, the function returns `false` and a string indicating the error.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.query "Link to this")

playdate.network.http:query(path, \[headers\], data)

Opens the connection to the server if it’s not already open (e.g. from a previous request with keep-alive enabled) and sends the given request with the given path, additional _headers_ if specified, and the provided _data_. The _headers_ argument can either be a string containing all of the headers to send (with newlines between individual headers), an array of strings, or a table of key/value pairs. If there is only one argument after _path_ it is assumed to be _data_.

If the request is successfully queued, the function returns `true`. On error, the function returns `false` and a string indicating the error.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.post "Link to this")

playdate.network.http:post(path, \[headers\], data)

Equivalent to calling `playdate.network.http:query()` with _method_ equal to `POST`.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.getError "Link to this")

playdate.network.http:getError()

Returns a text description of the last error on the connection, or nil if no error occurred.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.getProgress "Link to this")

playdate.network.http:getProgress()

Returns two values: the number of bytes already read from the connection and the total bytes the server plans to send.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.getBytesAvailable "Link to this")

playdate.network.http:getBytesAvailable()

Returns the number of bytes currently available for reading from the connection.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.setReadTimeout "Link to this")

playdate.network.http:setReadTimeout(seconds)

Sets the length of time, in seconds, `playdate.network.http:read()` will wait for incoming data before returning. The default value is one second.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.setReadBufferSize "Link to this")

playdate.network.http:setReadBufferSize(bytes)

Sets the size of the connection’s read buffer.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.read "Link to this")

playdate.network.http:read(\[length\])

On success, returns up to `length` bytes (maximum 64KB) from the connection. If `length` is more than the number of bytes available the function will wait for more data up to the length of time set by `setReadTimeout()` (default one second).

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.getResponseStatus "Link to this")

playdate.network.http:getResponseStatus()

Returns the HTTP status response code, if the request response headers have been received and parsed.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.getResponseHeaders "Link to this")

playdate.network.http:getResponseHeaders()

Returns a table containing the key/value pairs in the HTTP response headers, or nil if no headers were received.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.setRequestCallback "Link to this")

playdate.network.http:setRequestCallback(function)

Sets a function to be called when response data is available.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.setHeadersReadCallback "Link to this")

playdate.network.http:setHeadersReadCallback(function)

Sets a function to be called after the connection has parsed the headers from the server response. At this point, `getResponseStatus()` and `getProgress()` can be used to query the status and size of the response, and `get()`/ `post()` can queue another request if `connection:setKeepAlive(true)` was set.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.setRequestCompleteCallback "Link to this")

playdate.network.http:setRequestCompleteCallback(function)

Sets a function to be called when all data for the request has been received (if the response contained a Content-Length header and the size is known) or the request times out.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.http.setConnectionClosedCallback "Link to this")

playdate.network.http:setConnectionClosedCallback(function)

Sets a function to be called when the server has closed the connection.

#### [Link to this](http://sdk.play.date/inside-playdate/\#M-network.tcp "Link to this") TCP

[Link to this](http://sdk.play.date/inside-playdate/#f-network.tcp.new "Link to this")

playdate.network.tcp.new(server, port, \[usessl\], \[reason\])

Returns a `playdate.network.tcp` object for connecting to the given server. The default value for `usessl` is false. If the user has not yet given permission for the device to connect to the server, the game is paused while the system asks the user to allow or deny network access for the provided `reason`, if one is given. Since the system uses a coroutine `yield()` to show the dialog to request access (if not already given), it cannot be called at load time or from an input handler or other system callback.

[Link to this](http://sdk.play.date/inside-playdate/#f-network.tcp.requestAccess "Link to this")

playdate.network.tcp.requestAccess(\[server\], \[port\], \[reason\])

`playdate.network.tcp.new()` will automatically request access if needed (and note that `new()` only creates an object for connecting, doesn’t open the connection until `open()` is called) but if you want to present the access dialog ahead of time you can use this function. Notably, this lets you request access to all servers by leaving the `server` field empty, or all subdomains of a domain by passing in the parent. Access to all ports on a given server can be requested by leaving `port` empty. Note that this function uses a coroutine `yield()` to pause the runtime while the permission dialog is up, so it can’t be called immediately at startup, must be called from a `playdate.update()` context

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.setConnectTimeout "Link to this")

playdate.network.tcp:setConnectTimeout(seconds)

Sets the length of time (in seconds) to wait for the connection to the server to be made.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.open "Link to this")

playdate.network.tcp:open(connectCallback)

Attempts to open the TCP connection. `connectCallback` is a function to be called when the connection either succeeds or fails. The function is called with a boolean indicating whether the connection was successful, and an error string if the connection failed.

```
connection:open(function tcpConnectCallback(connected, err)
        if connected then print("connected!") else print("connection failed: "..err) end
end)
```

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.close "Link to this")

playdate.network.tcp:close()

Closes the connection. `open()` may be called again after this to reopen the connection to the server.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.getBytesAvailable "Link to this")

playdate.network.tcp:getBytesAvailable()

Returns the number of bytes currently available in the connection’s read buffer for reading from the connection.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.setReadTimeout "Link to this")

playdate.network.tcp:setReadTimeout(seconds)

Sets the length of time, in seconds, `playdate.network.tcp:read()` will wait for incoming data before returning. The default value is one second.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.setReadBufferSize "Link to this")

playdate.network.tcp:setReadBufferSize(bytes)

Sets the size of the connection’s read buffer.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.read "Link to this")

playdate.network.tcp:read(\[length\])

On success, returns up to `length` bytes (maximum 64KB) from the connection as well as the number of bytes that were read. If `length` is more than the number of bytes available the function will wait for more data up to the length of time set by `setReadTimeout()` (default one second).

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.write "Link to this")

playdate.network.tcp:write(data)

Attempts to write the given data to the connection. On success, returns `true`; on failure, returns `false` and a string describing the error.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.getError "Link to this")

playdate.network.tcp:getError()

Returns a text description of the last error on the connection, or nil if no error occurred.

[Link to this](http://sdk.play.date/inside-playdate/#m-network.tcp.setConnectionClosedCallback "Link to this")

playdate.network.tcp:setConnectionClosedCallback(function)

Sets a function to be called when the server has closed the connection.

### [Link to this](http://sdk.play.date/inside-playdate/\#M-pathfinder "Link to this") 7.25. Pathfinding

An implementation of the popular A\* pathfinding algorithm. To find a path first create a [playdate.pathfinder.graph](http://sdk.play.date#C-playdate.pathfinder.graph) containing connected [playdate.pathfinder.nodes](http://sdk.play.date#C-playdate.pathfinder.node) then call [findPath](http://sdk.play.date#m-pathfinder.graph.findPath) on the graph. A heuristic function callback can be specified for determining an estimate of the distance between two nodes, otherwise the manhattan distance between nodes will be used. In that case it is important to set appropriate x and y values on the nodes.

|     |     |
| --- | --- |
| Tip | Example code: `<Playdate SDK>/Examples/Pathfinder/` |

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-pathfinder.graph "Link to this") Graph

[Link to this](http://sdk.play.date/inside-playdate/#f-pathfinder.graph.new "Link to this")

playdate.pathfinder.graph.new(\[nodeCount, \[coordinates\]\])

Returns a new empty [playdate.pathfinder.graph](http://sdk.play.date#C-playdate.pathfinder.graph) object.

If `nodeCount` is supplied, that number of nodes will be allocated and added to the graph. Their IDs will be set from 1 to `nodeCount`.

`coordinates`, if supplied, should be a table containing tables of x, y values, indexed by node IDs. For example, `{{10, 10}, {50, 30}, {20, 100}, {100, 120}, {160, 130}}`.

[Link to this](http://sdk.play.date/inside-playdate/#f-pathfinder.graph.new2DGrid "Link to this")

playdate.pathfinder.graph.new2DGrid(width, height, \[allowDiagonals, \[includedNodes\]\])

Convenience function that returns a new [playdate.pathfinder.graph](http://sdk.play.date#C-playdate.pathfinder.graph) object containing nodes for for each grid position, even if not connected to any other nodes. This allows for easier graph modification once the graph is generated. Weights for connections between nodes are set to 10 for horizontal and vertical connections and 14 for diagonal connections (if included), as this tends to produce nicer paths than using uniform weights. Nodes have their indexes set from 1 to _width_ \\* _height_, and have their _x, y_ values set appropriately for the node’s position.

- _width_: The width of the grid to be created.

- _height_: The height of the grid to be created.

- _allowDiagonals_: If true, diagonal connections will also be created.

- _includedNodes_: A one-dimensional array of length _width_ \\* _height_. Each entry should be a 1 or a 0 to indicate nodes that should be connected to their neighbors and nodes that should not have any connections added. If not provided, all nodes will be connected to their neighbors.


[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.addNewNode "Link to this")

playdate.pathfinder.graph:addNewNode(id, \[x, y, \[connectedNodes, weights, addReciprocalConnections\]\])

Creates a new [playdate.pathfinder.node](http://sdk.play.date#C-playdate.pathfinder.node) and adds it to the graph.

- _id_: id value for the new node.

- _x_: Optional x value for the node.

- _y_: Optional y value for the node.

- _connectedNodes_: Array of existing nodes to create connections to from the new node.

- _weights_: Array of weights for the new connections. Array must be the same length as _connectedNodes_. Weights affect the path the A\* algorithm will solve for. A longer, lighter-weighted path will be chosen over a shorter heavier path, if available.

- _addReciprocalConnections_: If true, connections will also be added in the reverse direction for each node.


[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.addNewNodes "Link to this")

playdate.pathfinder.graph:addNewNodes(count)

Creates _count_ new nodes, adding them to the graph, and returns them in an array-style table. The new node’s _id\_s will be assigned values 1 through \_count_-1.

This method is useful to improve performance if many nodes need to be allocated at once rather than one at a time, for example when creating a new graph.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.addNode "Link to this")

playdate.pathfinder.graph:addNode(node, \[connectedNodes, weights, addReciprocalConnections\])

Adds an already-existing node to the graph. The node must have originally belonged to the same graph.

- _node_: Node to be added to the graph.

- _connectedNodes_: Array of existing nodes to create connections to from the new node.

- _weights_: Array of weights for the new connections. Array must be the same length as _connectedNodes_. Weights affect the path the A\* algorithm will solve for. A longer, lighter-weighted path will be chosen over a shorter heavier path, if available.

- _addReciprocalConnections_: If true, connections will also be added in the reverse direction for each connection added.


[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.addNodes "Link to this")

playdate.pathfinder.graph:addNodes(nodes)

Adds an array of already-existing nodes to the graph.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.allNodes "Link to this")

playdate.pathfinder.graph:allNodes()

Returns an array containing all nodes in the graph.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.removeNode "Link to this")

playdate.pathfinder.graph:removeNode(node)

Removes node from the graph. Also removes all connections to and from the node.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.removeNodeWithXY "Link to this")

playdate.pathfinder.graph:removeNodeWithXY(x, y)

Returns the first node found with coordinates matching _x, y_, after removing it from the graph and removing all connections to and from the node.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.removeNodeWithID "Link to this")

playdate.pathfinder.graph:removeNodeWithID(id)

Returns the first node found with a matching _id_, after removing it from the graph and removing all connections to and from the node.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.nodeWithID "Link to this")

playdate.pathfinder.graph:nodeWithID(id)

Returns the first node found in the graph with a matching _id_, or nil if no such node is found.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.nodeWithXY "Link to this")

playdate.pathfinder.graph:nodeWithXY(x, y)

Returns the first node found in the graph with matching _x_ and _y_ values, or nil if no such node is found.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.addConnections "Link to this")

playdate.pathfinder.graph:addConnections(connections)

`connections` should be a table of array-style tables. The keys of the outer table should correspond to node IDs, while the inner array should be a series if connecting node ID and weight combinations that will be assigned to that node. For example, `{[1]={2, 10, 3, 12}, [2]={1, 20}, [3]={1, 20, 2, 10}}` will create a connection from node ID 1 to node ID 2 with a weight of 10, and a connection to node ID 3 with a weight of 12, and so on for the other entries.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.addConnectionToNodeWithID "Link to this")

playdate.pathfinder.graph:addConnectionToNodeWithID(fromNodeID, toNodeID, weight, addReciprocalConnection)

Adds a connection from the node with `id` `fromNodeID` to the node with `id` `toNodeID` with a weight value of `weight`. Weights affect the path the A\* algorithm will solve for. A longer, lighter-weighted path will be chosen over a shorter heavier path, if available. If `addReciprocalConnection` is true, the reverse connection will also be added.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.removeAllConnections "Link to this")

playdate.pathfinder.graph:removeAllConnections()

Removes all connections from all nodes in the graph.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.removeAllConnectionsFromNodeWithID "Link to this")

playdate.pathfinder.graph:removeAllConnectionsFromNodeWithID(id, \[removeIncoming\])

Removes all connections from the matching node.

If `removeIncoming` is true, all connections from other nodes to the calling node are also removed. False by default. Please note: this can signficantly increase the time this function takes as it requires a full search of the graph - O(1) vs O(n)).

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.findPath "Link to this")

playdate.pathfinder.graph:findPath(startNode, goalNode, \[heuristicFunction, \[findPathToGoalAdjacentNodes\]\])

Returns an array of nodes representing the path from _startNode_ to _goalNode_, or _nil_ if no path can be found.

- _heuristicFunction_: If provided, this function should be of the form _function(startNode, goalNode)_ and should return an integer value estimate or underestimate of the distance from _startNode_ to _goalNode_. If not provided, a manhattan distance function will be used to calculate the estimate. This requires that the _x, y_ values of the nodes in the graph have been set properly.

- _findPathToGoalAdjacentNodes_: If true, a path will be found to any node adjacent to the goal node, based on the _x, y_ values of those nodes and the goal node. This does not rely on connections between adjacent nodes and the goal node, which can be entirely disconnected from the rest of the graph.


[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.findPathWithIDs "Link to this")

playdate.pathfinder.graph:findPathWithIDs(startNodeID, goalNodeID, \[heuristicFunction, \[findPathToGoalAdjacentNodes\]\])

Works the same as [findPath](http://sdk.play.date#m-pathfinder.graph.findPath), but looks up nodes to find a path between using startNodeID and goalNodeID and returns a list of nodeIDs rather than the nodes themselves.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.graph.setXYForNodeWithID "Link to this")

playdate.pathfinder.graph:setXYForNodeWithID(id, x, y)

Sets the matching node’s `x` and `y` values.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-playdate.pathfinder.node "Link to this") Node

You can directly read or write **x**, **y** and **id** values on a playdate.pathfinder.node.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.node.addConnection "Link to this")

playdate.pathfinder.node:addConnection(node, weight, addReciprocalConnection)

Adds a new connection between nodes.

- _node_: The node the new connection will point to.

- _weight_: Weight for the new connection. Weights affect the path the A\* algorithm will solve for. A longer, lighter-weighted path will be chosen over a shorter heavier path, if available.

- _addReciprocalConnection_: If true, a second connection will be created with the same weight in the opposite direction.


[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.node.addConnections "Link to this")

playdate.pathfinder.node:addConnections(nodes, weights, addReciprocalConnections)

Adds a new connection to each node in the nodes array.

- _nodes_: An array of nodes which the new connections will point to.

- _weights_: An array of weights for the new connections. Must be of the same length as the nodes array. Weights affect the path the A\* algorithm will solve for. A longer, lighter-weighted path will be chosen over a shorter heavier path, if available.

- _addReciprocalConnections_: If true, connections will also be added in the reverse direction for each node.


[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.node.addConnectionToNodeWithXY "Link to this")

playdate.pathfinder.node:addConnectionToNodeWithXY(x, y, weight, addReciprocalConnection)

Adds a connection to the first node found with matching _x_ and _y_ values, if it exists.

- _weight_: The weight for the new connection. Weights affect the path the A\* algorithm will solve for. A longer, lighter-weighted path will be chosen over a shorter heavier path, if available.

- _addReciprocalConnections_: If true, a connection will also be added in the reverse direction, from the node at x, y to the caller.


[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.node.connectedNodes "Link to this")

playdate.pathfinder.node:connectedNodes()

Returns an array of nodes that have been added as connections to this node.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.node.removeConnection "Link to this")

playdate.pathfinder.node:removeConnection(node, \[removeReciprocal\])

Removes a connection to node, if it exists. If _removeReciprocal_ is true the reverse connection will also be removed, if it exists.

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.node.removeAllConnections "Link to this")

playdate.pathfinder.node:removeAllConnections(\[removeIncoming\])

Removes all connections from the calling node.

If `removeIncoming` is true, all connections from other nodes to the calling node are also removed. False by default. Please note: this can signficantly increase the time this function takes as it requires a full search of the graph - O(1) vs O(n)).

[Link to this](http://sdk.play.date/inside-playdate/#m-pathfinder.node.setXY "Link to this")

playdate.pathfinder.node:setXY(x, y)

Sets the _x_ and _y_ values for the node.

### [Link to this](http://sdk.play.date/inside-playdate/\#power "Link to this") 7.26. Power

[Link to this](http://sdk.play.date/inside-playdate/#f-getPowerStatus "Link to this")

playdate.getPowerStatus()

Returns a table holding booleans with the following keys:

- _charging_: The battery is actively being charged

- _USB_: There is a powered USB cable connected

- _screws_: There is 5V being applied to the corner screws (via the dock, for example)


[Link to this](http://sdk.play.date/inside-playdate/#f-getBatteryPercentage "Link to this")

playdate.getBatteryPercentage()

Returns a value from 0-100 denoting the current level of battery charge. 0 = empty; 100 = full.

[Link to this](http://sdk.play.date/inside-playdate/#f-getBatteryVoltage "Link to this")

playdate.getBatteryVoltage()

Returns the battery’s current voltage level.

### [Link to this](http://sdk.play.date/inside-playdate/\#simulator "Link to this") 7.27. Simulator-only functionality

[Link to this](http://sdk.play.date/inside-playdate/#v-isSimulator "Link to this")

playdate.isSimulator

This variable—not a function, so don’t invoke with _()_—it is set to 1 when running inside of the Simulator and is _nil_ otherwise.

[Link to this](http://sdk.play.date/inside-playdate/#f-simulator.writeToFile "Link to this")

playdate.simulator.writeToFile(image, path)

Writes an image to a PNG file at the path specified. Only available on the Simulator.

|     |     |
| --- | --- |
| Note | _path_ represents a path on your development computer, not the Playdate filesystem. It’s recommended you prefix your path with `~/` to ensure you are writing to a writeable directory, for example, `~/myImageFile.png`. Please include the `.png` file extension in your path name. Any directories in your path must already exist on your development computer in order for the file to be written. |

[Link to this](http://sdk.play.date/inside-playdate/#f-simulator.exit "Link to this")

playdate.simulator.exit()

Quits the Playdate Simulator app.

[Link to this](http://sdk.play.date/inside-playdate/#f-simulator.getURL "Link to this")

playdate.simulator.getURL(url)

Returns the contents of the URL _url_ as a string.

[Link to this](http://sdk.play.date/inside-playdate/#f-clearConsole "Link to this")

playdate.clearConsole()

Clears the simulator console.

[Link to this](http://sdk.play.date/inside-playdate/#f-setDebugDrawColor "Link to this")

playdate.setDebugDrawColor(r, g, b, a)

Sets the color of the [playdate.debugDraw()](http://sdk.play.date#c-debugDraw) overlay image. Values are in the range 0-1.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_simulator_debug_callbacks "Link to this") Simulator debug callbacks

These callbacks are only invoked when your game is running in the Simulator.

[Link to this](http://sdk.play.date/inside-playdate/#c-keyPressed "Link to this")

playdate.keyPressed(key)

Lets you act on keyboard keypresses when running in the Simulator ONLY. These can be useful for adding debugging functions that can be enabled via your keyboard.

|     |     |
| --- | --- |
| Note | It is possible test a game on Playdate hardware and trap computer keyboard keypresses if you are using the Simulator’s `Control Device with Simulator` option. |

`key` is a string containing the character pressed or released on the keyboard. Note that:

- The key in question needs to have a textual representation or these functions will not be called. For instance, alphanumeric keys will call these functions; keyboard directional arrows will not.

- If the keypress in question is already in use by the Simulator for another purpose (say, to control the d-pad or A/B buttons), these functions will not be called.

- If _key_ is an alphabetic character, the value will always be lowercase, even if the user deliberately typed an uppercase character.


[Link to this](http://sdk.play.date/inside-playdate/#c-keyReleased "Link to this")

playdate.keyReleased(key)

Lets you act on keyboard key releases when running in the Simulator ONLY. These can be useful for adding debugging functions that can be enabled via your keyboard.

[Link to this](http://sdk.play.date/inside-playdate/#c-debugDraw "Link to this")

playdate.debugDraw()

Called immediately after [playdate.update()](http://sdk.play.date#c-update), any drawing performed during this callback is overlaid on the display in 50% transparent red (or another color selected with [playdate.setDebugDrawColor()](http://sdk.play.date#f-setDebugDrawColor)).

White pixels are drawn in the [debugDrawColor](http://sdk.play.date#f-setDebugDrawColor). Black pixels are transparent.

### [Link to this](http://sdk.play.date/inside-playdate/\#M-sound "Link to this") 7.28. Sound

The Playdate audio engine provides [sample playback](http://sdk.play.date#C-sound.sampleplayer) from memory for short on-demand samples, [file streaming](http://sdk.play.date#C-sound.fileplayer) for playing longer files (uncompressed, MP3, and ADPCM formats), and a [synthesis](http://sdk.play.date#C-sound.synth) library for generating "computer-y" sounds. Sound sources are grouped into [channels](http://sdk.play.date#C-sound.channel), which can be panned separately, and various [effects](http://sdk.play.date#C-sound.effect) may be applied to the channels. Additionally, [signals](http://sdk.play.date#C-sound.signal) can automate various parameters of the sound objects.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.getSampleRate "Link to this")

playdate.sound.getSampleRate()

Returns the sample rate of the audio system (44100). The sample rate is determined by the hardware, and is not currently mutable.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.sampleplayer "Link to this") Sampleplayer

The sampleplayer class is used for playing short samples like sound effects. Audio data is loaded into memory at instantiation, so it plays with little overhead. For longer audio like background music, the [fileplayer](http://sdk.play.date#C-sound.fileplayer) class may be more appropriate; there, audio data is streamed from disk as it’s played and only a small portion of the data is in memory at any given time.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.sampleplayer.new "Link to this")

playdate.sound.sampleplayer.new(path)

Returns a new playdate.sound.sampleplayer object, with the sound data loaded in memory. If the sample can’t be loaded, the function returns nil and a second value containing the error.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.copy "Link to this")

playdate.sound.sampleplayer:copy()

Returns a new playdate.sound.sampleplayer with the same sample, volume, and rate as the given sampleplayer.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.play "Link to this")

playdate.sound.sampleplayer:play(\[repeatCount\], \[rate\])

Starts playing the sample. If _repeatCount_ is greater than one, it loops the given number of times. If zero, it loops endlessly until it is stopped with [playdate.sound.sampleplayer:stop()](http://sdk.play.date#m-sound.sampleplayer.stop). If _rate_ is set, the sample will be played at the given rate instead of the rate previous set with [playdate.sound.sampleplayer.setRate()](http://sdk.play.date#m-sound.sampleplayer.setRate).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.playAt "Link to this")

playdate.sound.sampleplayer:playAt(when, \[vol\], \[rightvol\], \[rate\])

Schedules the sound for playing at device time _when_. If _vol_ is specified, the sample will be played at level _vol_ (with optional separate right channel volume _rightvol_), otherwise it plays at the volume set by [playdate.sound.sampleplayer.setVolume()](http://sdk.play.date#m-sound.sampleplayer.setVolume). Note that the _when_ argument is an offset in the audio device’s time scale, as returned by [playdate.sound.getCurrentTime()](http://sdk.play.date#f-sound.getCurrentTime); it is **not** relative to the current time! If _when_ is less than the current audio time, the sample is played immediately. If _rate_ is set, the sample will be played at the given rate instead of the rate previously set with [playdate.sound.sampleplayer.setRate()](http://sdk.play.date#m-sound.sampleplayer.setRate).

Only one event can be queued at a time. If `playAt()` is called while another event is queued, it will overwrite it with the new values.

The function returns true if the sample was successfully added to the sound channel, otherwise false (i.e., if the channel is full).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.setVolume "Link to this")

playdate.sound.sampleplayer:setVolume(left, \[right\])

Sets the playback volume (0.0 - 1.0) for left and right channels. If the optional _right_ argument is omitted, it is the same as _left_. If the sampleplayer is currently playing using the default volume (that is, it wasn’t triggered by `playAt()` with a volume given) it also changes the volume of the playing sample.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.getVolume "Link to this")

playdate.sound.sampleplayer:getVolume()

Returns the playback volume for the sampleplayer, a single value for mono sources or a pair of values (left, right) for stereo sources.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.setLoopCallback "Link to this")

playdate.sound.sampleplayer:setLoopCallback(callback, \[arg\])

Sets a function to be called every time the sample loops. The sample object is passed to this function as the first argument, and the optional _arg_ argument is passed as the second.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.setPlayRange "Link to this")

playdate.sound.sampleplayer:setPlayRange(start, end)

Sets the range of the sample to play. _start_ and _end_ are frame offsets from the beginning of the sample.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.setPaused "Link to this")

playdate.sound.sampleplayer:setPaused(flag)

Pauses or resumes playback.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.isPlaying "Link to this")

playdate.sound.sampleplayer:isPlaying()

Returns a boolean indicating whether the sample is playing.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.stop "Link to this")

playdate.sound.sampleplayer:stop()

Stops playing the sample.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.setFinishCallback "Link to this")

playdate.sound.sampleplayer:setFinishCallback(func, \[arg\])

Sets a function to be called when playback has completed. The sample object is passed to this function as the first argument, and the optional _arg_ argument is passed as the second.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.getLength "Link to this")

playdate.sound.sampleplayer:getLength()

Returns the length of the sampleplayer’s sample, in seconds. Length is not scaled by playback rate.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.setRate "Link to this")

playdate.sound.sampleplayer:setRate(rate)

Sets the playback rate for the sample. 1.0 is normal speed, 0.5 is down an octave, 2.0 is up an octave, etc. Sampleplayers can also play samples backwards, by setting a negative rate; note, however, this does not work with ADPCM-encoded files.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.getRate "Link to this")

playdate.sound.sampleplayer:getRate()

Returns the playback rate for the sample.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.setRateMod "Link to this")

playdate.sound.sampleplayer:setRateMod(signal)

Sets the [signal](http://sdk.play.date#C-sound.signal) to use as a rate modulator, added to the rate set with [playdate.sound.sampleplayer:setRate()](http://sdk.play.date#m-sound.sampleplayer.setRate). Set to _nil_ to clear the modulator.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.setOffset "Link to this")

playdate.sound.sampleplayer:setOffset(seconds)

Sets the current offset of the sampleplayer, in seconds. This value is not adjusted for rate.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sampleplayer.getOffset "Link to this")

playdate.sound.sampleplayer:getOffset()

Returns the current offset of the sampleplayer, in seconds. This value is not adjusted for rate.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.fileplayer "Link to this") Fileplayer

The fileplayer class is used for streaming audio from a file on disk. This requires less memory than keeping all of the file’s data in memory (as with the [sampleplayer](http://sdk.play.date#C-sound.sampleplayer)), but can increase overhead at run time.

|     |     |
| --- | --- |
| Note | Fileplayer can play MP3 files, but MP3 decoding is CPU-intensive. For a balance of good performance and small file size, we recommend encoding audio into [ADPCM .wav files](http://sdk.play.date#M-sound-prep). |

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.fileplayer.new-empty "Link to this")

playdate.sound.fileplayer.new(\[buffersize\])

Returns a fileplayer object, which can stream samples from disk. The file to play is set with the [playdate.sound.fileplayer:load()](http://sdk.play.date#m-sound.fileplayer.load) function.

If given, _buffersize_ specifies the size in seconds of the fileplayer’s data buffer. A shorter value reduces the latency of a [playdate.sound.fileplayer:setOffset()](http://sdk.play.date#m-sound.fileplayer.setOffset) call, but increases the chance of a buffer underrun.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.fileplayer.new "Link to this")

playdate.sound.fileplayer.new(path, \[buffersize\])

Returns a fileplayer object for streaming samples from the file at _path_. Note that the file isn’t loaded until [playdate.sound.fileplayer:play()](http://sdk.play.date#m-sound.fileplayer.play) or [playdate.sound.fileplayer:setBufferSize()](http://sdk.play.date#m-sound.fileplayer.setBufferSize) is called, in order to reduce initialization overhead.

If given, _buffersize_ specifies the size in seconds of the fileplayer’s data buffer. A shorter value reduces the latency of a [playdate.sound.fileplayer:setOffset()](http://sdk.play.date#m-sound.fileplayer.setOffset) call, but increases the chance of a buffer underrun.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.load "Link to this")

playdate.sound.fileplayer:load(path)

Instructs the fileplayer to load the file at _path_ when [play()](http://sdk.play.date#m-sound.fileplayer.play) is called on it. The fileplayer must not be playing when this function is called. The fileplayer’s play offset is reset to the beginning of the file, and its loop range is cleared.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.play "Link to this")

playdate.sound.fileplayer:play(\[repeatCount\])

Opens and starts playing the file, first creating and filling a 1/4 second playback buffer if a buffer size hasn’t been set yet.

If repeatCount is set, playback repeats when it reaches the end of the file or the end of the [loop range](http://sdk.play.date#m-sound.fileplayer.setLoopRange) if one is set. After the loop has run _repeatCount_ times, it continues playing to the end of the file. A _repeatCount_ of zero loops endlessly. If repeatCount is not set, the file plays once.

The function returns true if the file was successfully opened and the fileplayer added to the sound channel, otherwise false and a string describing the error.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.stop "Link to this")

playdate.sound.fileplayer:stop()

Stops playing the file, resets the playback offset to zero, and calls the finish callback.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.pause "Link to this")

playdate.sound.fileplayer:pause()

Stops playing the file. A subsequent play() call resumes playback from where it was paused.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.isPlaying "Link to this")

playdate.sound.fileplayer:isPlaying()

Returns a boolean indicating whether the fileplayer is playing.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.getLength "Link to this")

playdate.sound.fileplayer:getLength()

Returns the length, in seconds, of the audio file.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.setFinishCallback "Link to this")

playdate.sound.fileplayer:setFinishCallback(func, \[arg\])

Sets a function to be called when playback has completed. The fileplayer is passed as the first argument to _func_. The optional argument _arg_ is passed as the second.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.didUnderrun "Link to this")

playdate.sound.fileplayer:didUnderrun()

Returns the fileplayer’s underrun flag, indicating that the player ran out of data. This can be checked in the finish callback function to check for an underrun error.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.setStopOnUnderrun "Link to this")

playdate.sound.fileplayer:setStopOnUnderrun(flag)

By default, if the fileplayer runs out of data it does not stop playback but instead restarts (after an audible stutter) as soon as data becomes available. Setting the flag to _true_ changes this behavior so that it stops playback and calls the fileplayer’s [finish callback](http://sdk.play.date#m-sound.fileplayer.setFinishCallback), if set.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.setLoopRange "Link to this")

playdate.sound.fileplayer:setLoopRange(start, \[end, \[loopCallback, \[arg\]\]\])

Provides a way to loop a portion of an audio file. In the following code:

```
local fp = playdate.sound.fileplayer.new( "myaudiofile" )
fp:setLoopRange( 10, 20 )
fp:play( 3 )
```

…the fileplayer will start playing from the beginning of the audio file, loop the 10-20 second range three times, and then stop playing.

_start_ and _end_ are specified in seconds. If _end_ is omitted, the end of the file is used. If the function _loopCallback_ is provided, it is called every time the player loops, with the fileplayer as the first argument and the optional _arg_ argument as the second.

|     |     |
| --- | --- |
| Important | The [fileplayer:play(\[repeatCount\])](http://sdk.play.date#m-sound.fileplayer.play) call needs to be invoked with a _repeatCount_ value of 0 (infinite looping), or 2 or greater in order for the looping action to happen. |

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.setLoopCallback "Link to this")

playdate.sound.fileplayer:setLoopCallback(callback, \[arg\])

Sets a function to be called every time the fileplayer loops. The fileplayer object is passed to this function as the first argument, and _arg_ as the second.

|     |     |
| --- | --- |
| Important | The [fileplayer:play(\[repeatCount\])](http://sdk.play.date#m-sound.fileplayer.play) call needs to be invoked with a _repeatCount_ value of 0 (infinite looping), or 2 or greater in order for the loop callback to be invoked. |

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.setBufferSize "Link to this")

playdate.sound.fileplayer:setBufferSize(seconds)

Sets the buffer size for the fileplayer, in seconds. Larger buffers protect against buffer underruns, but consume more memory. Calling this function also fills the output buffer if a source file has been set. On success, the function returns _true_; otherwise it returns _false_ and a string describing the error.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.setRate "Link to this")

playdate.sound.fileplayer:setRate(rate)

Sets the playback rate for the file. 1.0 is normal speed, 0.5 is down an octave, 2.0 is up an octave, etc. Unlike sampleplayers, fileplayers can’t play in reverse (i.e., rate < 0).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.getRate "Link to this")

playdate.sound.fileplayer:getRate()

Returns the playback rate for the file. as set with `setRate()`.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.setRateMod "Link to this")

playdate.sound.fileplayer:setRateMod(signal)

Sets the [signal](http://sdk.play.date#C-sound.signal) to use as a rate modulator, added to the rate set with [playdate.sound.fileplayer:setRate()](http://sdk.play.date#m-sound.fileplayer.setRate). Set to _nil_ to clear the modulator.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.setVolume "Link to this")

playdate.sound.fileplayer:setVolume(left, \[right, \[fadeSeconds, \[fadeCallback, \[arg\]\]\]\])

Sets the playback volume (0.0 - 1.0). If a single value is passed in, both left side and right side volume are set to the given value. If two values are given, volumes are set separately. The optional _fadeSeconds_ specifies the time it takes to fade from the current volume to the specified volume, in seconds. If the function _fadeCallback_ is given, it is called when the volume fade has completed. The fileplayer object is passed as the first argument to the callback, and the optional _arg_ argument is passed as the second.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.getVolume "Link to this")

playdate.sound.fileplayer:getVolume()

Returns the current volume for the fileplayer, a single value for mono sources or a pair of values (left, right) for stereo sources.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.setOffset "Link to this")

playdate.sound.fileplayer:setOffset(seconds)

Sets the current offset of the fileplayer, in seconds. This value is not adjusted for rate.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.fileplayer.getOffset "Link to this")

playdate.sound.fileplayer:getOffset()

Returns the current offset of the fileplayer, in seconds. This value is not adjusted for rate.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.sample "Link to this") Sample

playdate.sound.sample is an abstraction of an individual sound sample. If all you want to do is play
a single sound sample, you may wish to use [playdate.sound.sampleplayer](http://sdk.play.date#C-sound.sampleplayer) instead. However,
playdate.sound.sample exists so you can preload sounds and swap them in and out without fragmenting device memory.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.sample.new-path "Link to this")

playdate.sound.sample.new(path)

Returns a new playdate.sound.sample object, with the sound data loaded in memory. If the sample can’t be loaded, the function returns nil and a second value containing the error.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.sample.new "Link to this")

playdate.sound.sample.new(seconds, \[format\])

Returns a new playdate.sound.sample object, with a buffer size of _seconds_ in the given format. If _format_ is not specified, it defaults to [playdate.sound.kFormat16bitStereo](http://sdk.play.date#m-sound.sample.getFormat). When used with playdate.sound.sample:load(), this allows you to swap in a different sample without re-allocating the buffer, which could lead to memory fragmentation.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sample.getSubsample "Link to this")

playdate.sound.sample:getSubsample(startOffset, endOffset)

Returns a new subsample containing a subrange of the given sample. Offset values are in frames, not bytes.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sample.load "Link to this")

playdate.sound.sample:load(path)

Loads the sound data from the file at _path_ into an existing sample buffer. If there is no file at _path_, the function returns nil.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sample.decompress "Link to this")

playdate.sound.sample:decompress()

If the sample is ADPCM compressed, decompresses the sample data to 16-bit PCM data. This increases the sample’s memory footprint by 4x and does not affect the quality in any way, but it is necessary if you want to use the sample in a synth or play the file backwards. Returns `true` if successful, or `false` and an error message as a second return value if decompression failed.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sample.getSampleRate "Link to this")

playdate.sound.sample:getSampleRate()

Returns the sample rate as an integer, such as 44100 or 22050.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sample.getFormat "Link to this")

playdate.sound.sample:getFormat()

Returns the format of the sample, one of

- _playdate.sound.kFormat8bitMono_

- _playdate.sound.kFormat8bitStereo_

- _playdate.sound.kFormat16bitMono_

- _playdate.sound.kFormat16bitStereo_


[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sample.getLength "Link to this")

playdate.sound.sample:getLength()

Returns two values, the length of the available sample data and the size of the allocated buffer. Both values are measured in seconds. For a sample loaded from disk, these will be the same; for a sample used for recording, the available data may be less than the allocated size.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sample.save "Link to this")

playdate.sound.sample:save(filename)

Saves the sample to the given file. If `filename` has a `.wav` extension it will be saved in WAV format (and be unreadable by the Playdate sound functions), otherwise it will be saved in the Playdate pda format.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.channel "Link to this") Channel

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.channel.new "Link to this")

playdate.sound.channel.new()

Returns a new channel object and adds it to the global list.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.channel.remove "Link to this")

playdate.sound.channel:remove()

Removes the channel from the global list.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.channel.setVolume "Link to this")

playdate.sound.channel:setVolume(volume)

Sets the volume (0.0 - 1.0) for the channel.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.channel.getVolume "Link to this")

playdate.sound.channel:getVolume()

Gets the volume (0.0 - 1.0) for the channel.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.channel.setPan "Link to this")

playdate.sound.channel:setPan(pan)

Sets the pan parameter for the channel. -1 is left, 0 is center, and 1 is right.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.source "Link to this") Source

_playdate.sound.source_ is the parent class of our sound sources, [playdate.sound.fileplayer](http://sdk.play.date#C-sound.fileplayer), [playdate.sound.sampleplayer](http://sdk.play.date#C-sound.sampleplayer), [playdate.sound.synth](http://sdk.play.date#C-sound.synth), and [playdate.sound.instrument](http://sdk.play.date#C-sound.instrument).

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.playingSources "Link to this")

playdate.sound.playingSources()

Returns a list of all sources currently playing.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.synth "Link to this") Synth

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.synth.new_w "Link to this")

playdate.sound.synth.new(\[waveform\])

Returns a new synth object to play a waveform or wavetable. See [playdate.sound.synth:setWaveform](http://sdk.play.date#m-sound.synth.setWaveform) for `waveform` values.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.synth.new "Link to this")

playdate.sound.synth.new(sample, \[sustainStart, sustainEnd\])

Returns a new synth object to play a [Sample](http://sdk.play.date#C-sound.sample). Sample data must be uncompressed PCM, not ADPCM. An optional sustain region (measured in sample frames) defines a loop to play while the note is active. When the note ends, if an envelope has been set on the synth and the sustain range goes to the end of the sample (i.e. there’s no release section of the sample after the sustain range) then the sustain section continues looping during the envelope release; otherwise it plays through the end of the sample and stops. As a convenience, if `sustainStart` is greater than zero and `sustainEnd` isn’t given, it will be set to the length of the sample.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.copy "Link to this")

playdate.sound.synth:copy()

Returns a copy of the given synth.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.playNote "Link to this")

playdate.sound.synth:playNote(pitch, \[volume, \[length, \[when\]\]\])

Plays a note with the current waveform or sample.

- _pitch_: the pitch value is in Hertz. If a sample is playing, pitch=261.63 (C4) plays at normal speed



- in either function, a string like `Db3` can be used instead of a number


- _volume_: 0 to 1, defaults to 1

- _length_: in seconds. If omitted, note will play until you call noteOff()

- _when_: seconds since the sound engine started (see [playdate.sound.getCurrentTime](http://sdk.play.date#f-sound.getCurrentTime)). Defaults to the current time.


The function returns true if the synth was successfully added to the sound channel, otherwise false (i.e., if the channel is full).

If _pitch_ is zero, this function calls `noteOff()` instead of potentially adding a non-zero sample, or DC offset, to the output.

|     |     |
| --- | --- |
| Note | Synths currently only have a buffer of one note event. If you call _playNote()_ while another note is waiting to play, it will replace that note. To create a sequence of notes to play over a period of time, see [playdate.sound.sequence](http://sdk.play.date#C-sound.sequence). |

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.playMIDINote "Link to this")

playdate.sound.synth:playMIDINote(note, \[volume, \[length, \[when\]\]\])

Identical to [playNote](http://sdk.play.date#m-sound.synth.playNote) but uses a note name like "C4", or MIDI note number (60=C4, 61=C#4, etc.). In the latter case, fractional values are allowed.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.noteOff "Link to this")

playdate.sound.synth:noteOff()

Releases the note, if one is playing. The note will continue to be voiced through the release section of the synth’s envelope.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.stop "Link to this")

playdate.sound.synth:stop()

Stops the synth immediately, without playing the release part of the envelope.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.isPlaying "Link to this")

playdate.sound.synth:isPlaying()

Returns true if the synth is still playing, including the release phase of the envelope.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setAttack "Link to this")

playdate.sound.synth:setAttack(time)

Sets the attack time, in seconds.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setDecay "Link to this")

playdate.sound.synth:setDecay(time)

Sets the decay time, in seconds.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setSustain "Link to this")

playdate.sound.synth:setSustain(level)

Sets the sustain level, as a proportion of the total level (0.0 to 1.0).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setRelease "Link to this")

playdate.sound.synth:setRelease(time)

Sets the release time, in seconds.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.clearEnvelope "Link to this")

playdate.sound.synth:clearEnvelope()

Clears the synth’s envelope settings.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setEnvelopeCurvature "Link to this")

playdate.sound.synth:setEnvelopeCurvature(amount)

Smoothly changes the envelope’s shape from linear (amount=0) to exponential (amount=1).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.getEnvelope "Link to this")

playdate.sound.synth:getEnvelope()

Returns the synth’s envelope as a [playdate.sound.envelope](http://sdk.play.date#C-sound.envelope) object.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setFinishCallback "Link to this")

playdate.sound.synth:setFinishCallback(function)

Sets a function to be called when the synth stops playing.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setLegato "Link to this")

playdate.sound.synth:setLegato(flag)

Sets whether to use legato phrasing for the synth. If the legato flag is set and a new note starts while a previous note is still playing, the synth’s envelope remains in the sustain phase instead of starting a new attack.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setVolume "Link to this")

playdate.sound.synth:setVolume(left, \[right\])

Sets the synth volume. If a single value is passed in, sets both left side and right side volume to the given value. If two values are given, volumes are set separately.

Volume values are between 0.0 and 1.0.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.getVolume "Link to this")

playdate.sound.synth:getVolume()

Returns the current volume for the synth, a single value for mono sources or a pair of values (left, right) for stereo sources.

Volume values are between 0.0 and 1.0.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setWaveform "Link to this")

playdate.sound.synth:setWaveform(waveform)

Sets the waveform or [Sample](http://sdk.play.date#C-sound.sample) the synth plays. If a sample is given, its data must be uncompressed PCM, not ADPCM. Otherwise _waveform_ should be one of the following constants:

- _playdate.sound.kWaveSine_

- _playdate.sound.kWaveSquare_

- _playdate.sound.kWaveSawtooth_

- _playdate.sound.kWaveTriangle_

- _playdate.sound.kWaveNoise_

- _playdate.sound.kWavePOPhase_

- _playdate.sound.kWavePODigital_

- _playdate.sound.kWavePOVosim_


[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setWavetable "Link to this")

playdate.sound.synth:setWavetable(sample, samplesize, xsize, \[ysize\])

Sets a wavetable for the synth to play. Sample data must be 16-bit mono uncompressed. `samplesize` is the number of samples in each waveform "cell" in the table and must be a power of 2. `xsize` is the number of cells across the wavetable. If the wavetable is two-dimensional, `ysize` gives the number of cells in the y direction.

The synth’s "position" in the wavetable is set manually with [setParameter()](http://sdk.play.date#m-sound.synth.setParameter) or automated with [setParameterMod()](http://sdk.play.date#m-sound.synth.setParameterMod). In some cases it’s easier to use a parameter that matches the waveform position in the table, in others (notably when using envelopes and lfos) it’s more convenient to use a 0-1 scale, so there’s some redundancy here. Parameters are

- 1: x position, values are from 0 to the table width

- 2: x position, values are from 0 to 1, parameter is scaled up to table width


For 2-D tables ( `rowwidth` \> 0):

- 3: y position, values are from 0 to the table height

- 4: y position, values are from 0 to 1, parameter is scaled up to table height


##### [Link to this](http://sdk.play.date/inside-playdate/\#_synth_parameters "Link to this") Synth parameters

Some synth types have parameters that can be set manually or driven by a signal, such as an envelope or LFO. On the square waveform the single parameter changes the pulse width; the PO synths have 2 parameters each, changing various aspects of the generator algorithm; and wavetable synths have up to four, [described above](http://sdk.play.date#m-sound.synth.setWavetable).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.synth.setParameter "Link to this")

playdate.sound.synth:setParameter(parameter, value)

Sets the parameter at (1-based) position _num_ to the given value. Unless otherwise specified, _value_ ranges from 0 to 1.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.signal "Link to this") Signal

_playdate.sound.signal_ is the parent class of our low-frequency signals, [playdate.sound.lfo](http://sdk.play.date#C-sound.lfo), [playdate.sound.envelope](http://sdk.play.date#C-sound.envelope), and [playdate.sound.controlsignal](http://sdk.play.date#C-sound.controlsignal). These can be used to automate certain parameters in the audio engine.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.signal.setOffset "Link to this")

playdate.sound.signal:setOffset(offset)

Adds a constant offset to the signal (lfo, envelope, etc.).

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.signal.setScale "Link to this")

playdate.sound.signal:setScale(scale)

Multiplies the signal’s output by the given scale factor. The scale is applied before the offset.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.signal.getValue "Link to this")

playdate.sound.signal:getValue()

Returns the current output value of the signal.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.lfo "Link to this") LFO

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.lfo.new "Link to this")

playdate.sound.lfo.new(\[type\])

Returns a new LFO object, which can be used to modulate sounds. See [playdate.sound.lfo:setType()](http://sdk.play.date#m-sound.lfo.setType) for LFO types.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setType "Link to this")

playdate.sound.lfo:setType(type)

Sets the waveform of the LFO. Valid values are

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setArpeggio "Link to this")

playdate.sound.lfo:setArpeggio(note1, ...)

Sets the LFO type to arpeggio, where the given values are in half-steps from the center note. For example, the sequence (0, 4, 7, 12) plays the notes of a major chord.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setCenter "Link to this")

playdate.sound.lfo:setCenter(center)

playdate.sound.lfo:setOffset(center)

Sets the center value of the LFO.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setDepth "Link to this")

playdate.sound.lfo:setDepth(depth)

playdate.sound.lfo:setScale(depth)

Sets the depth of the LFO’s modulation.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setRate "Link to this")

playdate.sound.lfo:setRate(rate)

Sets the rate of the LFO, in cycles per second.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setPhase "Link to this")

playdate.sound.lfo:setPhase(phase)

Sets the current phase of the LFO, from 0 to 1.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setStartPhase "Link to this")

playdate.sound.lfo:setStartPhase(phase)

Sets the initial phase of the LFO, from 0 to 1.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setGlobal "Link to this")

playdate.sound.lfo:setGlobal(flag)

If an LFO is marked global, it is continuously updated whether or not it’s attached to any source.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setRetrigger "Link to this")

playdate.sound.lfo:setRetrigger(flag)

If retrigger is on, the LFO’s phase is reset to its initial phase (default 0) when a synth using the LFO starts playing a note.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.lfo.setDelay "Link to this")

playdate.sound.lfo:setDelay(holdoff, ramp)

Sets an initial holdoff time for the LFO where the LFO remains at its center value, and a ramp time where the value increases linearly to its maximum depth. Values are in seconds.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.lfo.getValue "Link to this")

playdate.sound.lfo:getValue()

Returns the current signal value of the LFO.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.envelope "Link to this") Envelope

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.envelope.new "Link to this")

playdate.sound.envelope.new(\[attack, decay, sustain, release\])

Creates a new envelope with the given (optional) parameters.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setAttack "Link to this")

playdate.sound.envelope:setAttack(attack)

Sets the envelope attack time to _attack_, in seconds.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setDecay "Link to this")

playdate.sound.envelope:setDecay(decay)

Sets the envelope decay time to _decay_, in seconds.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setSustain "Link to this")

playdate.sound.envelope:setSustain(sustain)

Sets the envelope sustain level to _sustain_, as a proportion of the maximum. For example, if the sustain level is 0.5, the signal value rises to its full value over the attack phase of the envelope, then drops to half its maximum over the decay phase, and remains there while the envelope is active.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setRelease "Link to this")

playdate.sound.envelope:setRelease(release)

Sets the envelope release time to _release_, in seconds.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setCurvature "Link to this")

playdate.sound.envelope:setCurvature(amount)

Smoothly changes the envelope’s shape from linear (amount=0) to exponential (amount=1).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setVelocitySensitivity "Link to this")

playdate.sound.envelope:setVelocitySensitivity(amount)

Changes the amount by which note velocity scales output level. At the default value of 1, output is proportional to velocity; at 0 velocity has no effect on output level.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setRateScaling "Link to this")

playdate.sound.envelope:setRateScaling(scaling, \[start, end\])

Scales the envelope rate according to the played note. For notes below `start`, the envelope’s set rate is used; for notes above `end` envelope rates are scaled by the `scaling` parameter. Between the two notes the scaling factor is interpolated from 1.0 to `scaling`. `start` and `end` are either MIDI note numbers or names like "C4". If omitted, the default range is C1 (36) to C5 (84).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setScale "Link to this")

playdate.sound.envelope:setScale(scale)

Sets the scale value for the envelope. The transformed envelope has an initial value of _offset_ and a maximum (minimum if _scale_ is negative) of _offset_ \+ _scale_.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setOffset "Link to this")

playdate.sound.envelope:setOffset(offset)

Sets the offset value for the envelope. The transformed envelope has an initial value of _offset_ and a maximum (minimum if _scale_ is negative) of _offset_ \+ _scale_.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setLegato "Link to this")

playdate.sound.envelope:setLegato(flag)

Sets whether to use legato phrasing for the envelope. If the legato flag is set, when the envelope is re-triggered before it’s released, it remains in the sustain phase instead of jumping back to the attack phase.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setRetrigger "Link to this")

playdate.sound.envelope:setRetrigger(flag)

If retrigger is on, the envelope always starts from 0 when a note starts playing, instead of the current value if it’s active.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.trigger "Link to this")

playdate.sound.envelope:trigger(velocity, \[length\])

Triggers the envelope at the given _velocity_. If a _length_ parameter is given, the envelope moves to the release phase after the given time. Otherwise, the envelope is held in the sustain phase until the trigger function is called again with _velocity_ equal to zero.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.envelope.setGlobal "Link to this")

playdate.sound.envelope:setGlobal(flag)

If an envelope is marked global, it is continuously updated whether or not it’s attached to any source.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.envelope.getValue "Link to this")

playdate.sound.envelope:getValue()

Returns the current signal value of the envelope.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.effect "Link to this") Effects

_playdate.sound.effect_ is the parent class of our sound effects, [playdate.sound.bitcrusher](http://sdk.play.date#C-sound.bitcrusher), [playdate.sound.twopolefilter](http://sdk.play.date#C-sound.twopolefilter), [playdate.sound.onepolefilter](http://sdk.play.date#C-sound.onepolefilter), [playdate.sound.ringmod](http://sdk.play.date#C-sound.ringmod), [playdate.sound.overdrive](http://sdk.play.date#C-sound.overdrive), and [playdate.sound.delayline](http://sdk.play.date#C-sound.delayline)

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.addEffect "Link to this")

playdate.sound.addEffect(effect)

Adds the given [playdate.sound.effect](http://sdk.play.date#C-sound.effect) to the default sound channel.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.removeEffect "Link to this")

playdate.sound.removeEffect(effect)

Removes the given effect from the default sound channel.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.bitcrusher "Link to this") Bitcrusher

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.bitcrusher.new "Link to this")

playdate.sound.bitcrusher.new()

Creates a new bitcrusher filter.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.bitcrusher.setMix "Link to this")

playdate.sound.bitcrusher:setMix(level)

Sets the wet/dry mix for the effect. A level of 1 (full wet) replaces the input with the effect output; 0 leaves the effect out of the mix.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.bitcrusher.setAmount "Link to this")

playdate.sound.bitcrusher:setAmount(amt)

Sets the amount of crushing to _amt_. Valid values are 0 (no effect) to 1 (quantizing output to 1-bit).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.bitcrusher.setUndersampling "Link to this")

playdate.sound.bitcrusher:setUndersampling(amt)

Sets the number of samples to repeat; 0 is no undersampling, 1 effectively halves the sample rate.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.ringmod "Link to this") Ring Modulator

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.ringmod.new "Link to this")

playdate.sound.ringmod.new()

Creates a new ring modulator filter.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.ringmod.setMix "Link to this")

playdate.sound.ringmod:setMix(level)

Sets the wet/dry mix for the effect. A level of 1 (full wet) replaces the input with the effect output; 0 leaves the effect out of the mix.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.ringmod.setFrequency "Link to this")

playdate.sound.ringmod:setFrequency(f)

Sets the ringmod frequency to _f_.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.onepolefilter "Link to this") One pole filter

The one pole filter is a simple low/high pass filter, with a single parameter describing the cutoff frequency: values above 0 (up to 1) are high-pass, values below 0 (down to -1) are low-pass.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.onepolefilter.new "Link to this")

playdate.sound.onepolefilter.new()

Returns a new one pole filter.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.onepolefilter.setMix "Link to this")

playdate.sound.onepolefilter:setMix(level)

Sets the wet/dry mix for the effect. A level of 1 (full wet) replaces the input with the effect output; 0 leaves the effect out of the mix.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.onepolefilter.setParameter "Link to this")

playdate.sound.onepolefilter:setParameter(p)

Sets the filter’s single parameter (cutoff frequency) to _p_.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.onepolefilter.setParameterMod "Link to this")

playdate.sound.onepolefilter:setParameterMod(m)

Sets a modulator for the filter’s parameter. Set to _nil_ to clear the modulator.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.twopolefilter "Link to this") Two pole filter

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.twopolefilter.new "Link to this")

playdate.sound.twopolefilter.new(type)

Creates a new two pole IIR filter of the given _type_:

- _playdate.sound.kFilterLowPass_ (or the string "lowpass" or "lopass")

- _playdate.sound.kFilterHighPass_ (or "highpass" or "hipass")

- _playdate.sound.kFilterBandPass_ (or "bandpass")

- _playdate.sound.kFilterNotch_ (or "notch")

- _playdate.sound.kFilterPEQ_ (or "peq")

- _playdate.sound.kFilterLowShelf_ (or "lowshelf" or "loshelf")

- _playdate.sound.kFilterHighShelf_ (or "highshelf" or "hishelf")


[Link to this](http://sdk.play.date/inside-playdate/#m-sound.twopolefilter.setMix "Link to this")

playdate.sound.twopolefilter:setMix(level)

Sets the wet/dry mix for the effect. A level of 1 (full wet) replaces the input with the effect output; 0 leaves the effect out of the mix.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.twopolefilter.setFrequency "Link to this")

playdate.sound.twopolefilter:setFrequency(f)

Sets the center frequency (in Hz) of the filter to _f_.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.twopolefilter.setResonance "Link to this")

playdate.sound.twopolefilter:setResonance(r)

Sets the resonance of the filter to _r_. Valid values are in the range 0-1. This parameter has no effect on shelf type filters.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.twopolefilter.setGain "Link to this")

playdate.sound.twopolefilter:setGain(g)

Sets the gain of the filter to _g_. Gain is only used in PEQ and shelf type filters.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.twopolefilter.setType "Link to this")

playdate.sound.twopolefilter:setType(type)

Sets the type of the filter to _type_.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.overdrive "Link to this") Overdrive

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.overdrive.new "Link to this")

playdate.sound.overdrive.new()

Creates a new overdrive effect.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.overdrive.setMix "Link to this")

playdate.sound.overdrive:setMix(level)

Sets the wet/dry mix for the effect. A level of 1 (full wet) replaces the input with the effect output; 0 leaves the effect out of the mix.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.overdrive.setGain "Link to this")

playdate.sound.overdrive:setGain(level)

Sets the gain of the filter.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.overdrive.setLimit "Link to this")

playdate.sound.overdrive:setLimit(level)

Sets the level where the amplified input clips.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.overdrive.setOffset "Link to this")

playdate.sound.overdrive:setOffset(level)

Adds an offset to the upper and lower limits to create an asymmetric clipping.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.delayline "Link to this") Delay line

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.delayline.new "Link to this")

playdate.sound.delayline.new(length)

Creates a new delay line effect, with the given length (in seconds).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.delayline.setMix "Link to this")

playdate.sound.delayline:setMix(level)

Sets the wet/dry mix for the effect. A level of 1 (full wet) replaces the input with the effect output; 0 leaves the effect out of the mix, which is useful if you’re using taps for varying delays.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.delayline.addTap "Link to this")

playdate.sound.delayline:addTap(delay)

Returns a new [playdate.sound.delaylinetap](http://sdk.play.date#C-sound.delaylinetap) on the delay line, at the given delay (which must be less than or equal to the delay line’s length).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.delayline.setFeedback "Link to this")

playdate.sound.delayline:setFeedback(level)

Sets the feedback level of the delay line.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.delaylinetap "Link to this") Delay line tap

_playdate.sound.delaylinetap_ is a subclass of _playdate.sound.source_. Note that a tap can be added to any channel, not just the channel the tap’s delay line is on.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.delaylinetap.setDelay "Link to this")

playdate.sound.delaylinetap:setDelay(time)

Sets the position of the tap on the delay line, up to the delay line’s length.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.delaylinetap.setDelayMod "Link to this")

playdate.sound.delaylinetap:setDelayMod(signal)

Sets a [signal](http://sdk.play.date#C-sound.signal) to modulate the tap delay. If the signal is continuous (e.g. an envelope or a triangle LFO, but not a square LFO) playback is sped up or slowed down to compress or expand time. Set to _nil_ to clear the modulator.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.delaylinetap.setVolume "Link to this")

playdate.sound.delaylinetap:setVolume(level)

Sets the tap’s volume.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.delaylinetap.getVolume "Link to this")

playdate.sound.delaylinetap:getVolume()

Returns the tap’s volume.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.delaylinetap.setFlipChannels "Link to this")

playdate.sound.delaylinetap:setFlipChannels(flag)

If set and the delay line is stereo, the tap outputs the delay line’s left channel to its right output and vice versa.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.sequence "Link to this") Sequence

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.sequence.new "Link to this")

playdate.sound.sequence.new(\[midi\_path\])

Creates a new sound sequence. If `midi_path` is given, it attempts to load data from the midi file into the sequence.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.play "Link to this")

playdate.sound.sequence:play(\[finishCallback\])

Starts playing the sequence. `finishCallback` is an optional function to be called when the sequence finishes playing or is stopped. The sequence is passed to the callback as its single argument.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.stop "Link to this")

playdate.sound.sequence:stop()

Stops playing the sequence.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.isPlaying "Link to this")

playdate.sound.sequence:isPlaying()

Returns true if the sequence is currently playing.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.getLength "Link to this")

playdate.sound.sequence:getLength()

Returns the length of the longest track in the sequence, in steps. See also [playdate.sound.track.getLength()](http://sdk.play.date#m-sound.track.getLength).

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.goToStep "Link to this")

playdate.sound.sequence:goToStep(step, \[play\])

Moves the play position for the sequence to step number `step`. If `play` is set, triggers the notes at that step.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.getCurrentStep "Link to this")

playdate.sound.sequence:getCurrentStep()

Returns the step number the sequence is currently at.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.setTempo "Link to this")

playdate.sound.sequence:setTempo(stepsPerSecond)

Sets the tempo of the sequence, in steps per second.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.getTempo "Link to this")

playdate.sound.sequence:getTempo()

Returns the tempo of the sequence, in steps per second.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.setLoops "Link to this")

playdate.sound.sequence:setLoops(startStep, endStep, \[loopCount\])

Sets the looping range of the sequence. If _loops_ is 0 or unset, the loop repeats endlessly.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.setLoops-2 "Link to this")

playdate.sound.sequence:setLoops(loopCount)

Same as above, with startStep set to 0 and endStep set to `sequence:getLength()`.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.getTrackCount "Link to this")

playdate.sound.sequence:getTrackCount()

Returns the number of tracks in the sequence.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.addTrack "Link to this")

playdate.sound.sequence:addTrack(\[track\])

Adds the given [playdate.sound.track](http://sdk.play.date#C-sound.track) to the sequence. If `track` omitted, the function creates and returns a new track.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.setTrackAtIndex "Link to this")

playdate.sound.sequence:setTrackAtIndex(n, track)

Sets the given [playdate.sound.track](http://sdk.play.date#C-sound.track) object at position `n` in the sequence.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.sequence.getTrackAtIndex "Link to this")

playdate.sound.sequence:getTrackAtIndex(n)

Returns the [playdate.sound.track](http://sdk.play.date#C-sound.track) object at position `n` in the sequence.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.track "Link to this") Track

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.track.new "Link to this")

playdate.sound.track.new()

Creates a new `playdate.sound.track` object.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.addNote2 "Link to this")

playdate.sound.track:addNote(step, note, length, \[velocity\])

playdate.sound.track:addNote(table)

Adds a single note event to the track, letting you specify `step`, `note`, `length`, and `velocity` directly. The second format allows you to pack them into a table, using the format returned by [getNotes()](http://sdk.play.date#m-sound.track.getNotes). The `note` argument can be a MIDI note number or a note name like "Db3". `length` is the length of the note in steps, not time—​that is, it follows the sequence’s tempo. The default velocity is 1.0.

See [setNotes()](http://sdk.play.date#m-sound.track.setNotes) for the ability to add more than one note at a time.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.setNotes "Link to this")

playdate.sound.track:setNotes(list)

Set multiple notes at once, each array element should be a table containing values for the keys The tables contain values for keys `step`, `note`, `length`, and `velocity`.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.getNotes "Link to this")

playdate.sound.track:getNotes(\[step\], \[endstep\])

Returns an array of tables representing the note events in the track.

The tables contain values for keys `step`, `note`, `length`, and `velocity`. If `step` is given, the function returns only the notes at that step; if both `step` and `endstep` are set, it returns the notes between the two steps (including notes at endstep). n.b. The `note` field in the event tables is always a MIDI note number value, even if the note was added using the string notation.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.removeNote "Link to this")

playdate.sound.track:removeNote(step, note)

Removes the note event at _step_ playing _note_.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.clearNotes "Link to this")

playdate.sound.track:clearNotes()

Clears all notes from the track.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.getLength "Link to this")

playdate.sound.track:getLength()

Returns the length, in steps, of the track—​that is, the step where the last note in the track ends.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.getNotesActive "Link to this")

playdate.sound.track:getNotesActive()

Returns the current number of notes active in the track.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.getPolyphony "Link to this")

playdate.sound.track:getPolyphony()

Returns the maximum number of notes simultaneously active in the track. (Known bug: this currently only works for midi files)

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.setInstrument "Link to this")

playdate.sound.track:setInstrument(inst)

Sets the [playdate.sound.instrument](http://sdk.play.date#C-sound.instrument) that this track plays. If `inst` is a [playdate.sound.synth](http://sdk.play.date#C-sound.synth), the function creates an instrument for the synth.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.getInstrument "Link to this")

playdate.sound.track:getInstrument()

Gets the [playdate.sound.instrument](http://sdk.play.date#C-sound.instrument) that this track plays.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.setMuted "Link to this")

playdate.sound.track:setMuted(flag)

Mutes or unmutes the track.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.addControlSignal "Link to this")

playdate.sound.track:addControlSignal(s)

Adds a [playdate.sound.controlsignal](http://sdk.play.date#C-sound.controlsignal) object to the track. Note that the signal must be assigned to a modulation input for it to have any audible effect. The input can be anywhere in the sound engine—​it’s not required to belong to the track in any way.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.track.getControlSignals "Link to this")

playdate.sound.track:getControlSignals()

Returns an array of [playdate.sound.controlsignal](http://sdk.play.date#C-sound.controlsignal) objects assigned to this track.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.instrument "Link to this") Instrument

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.instrument.new "Link to this")

playdate.sound.instrument.new(\[synth\])

Creates a new `playdate.sound.instrument` object. If `synth` is given, adds it as a voice for the instrument.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.addVoice "Link to this")

playdate.sound.instrument:addVoice(v, \[note\], \[rangeend\], \[transpose\])

Adds the given [playdate.sound.synth](http://sdk.play.date#C-sound.synth) to the instrument. If only the _note_ argument is given, the voice is only used for that note, and is transposed to play at normal speed (i.e. rate=1.0 for samples, or C4 for synths). If _rangeend_ is given, the voice is assigned to the range _note_ to _rangeend_, inclusive, with the first note in the range transposed to rate=1.0/C4. The `note` and `rangeend` arguments can be MIDI note numbers or note names like "Db3". The final transpose argument transposes the note played, in half-tone units.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.setPitchBend "Link to this")

playdate.sound.instrument:setPitchBend(amount)

Sets the pitch bend to be applied to the voices in the instrument, as a fraction of the full range.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.setPitchBendRange "Link to this")

playdate.sound.instrument:setPitchBendRange(halfsteps)

Sets the pitch bend range for the voices in the instrument. The default range is 12, for a full octave.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.setTranspose "Link to this")

playdate.sound.instrument:setTranspose(halfsteps)

Transposes all voices in the instrument. _halfsteps_ can be a fractional value.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.playNote "Link to this")

playdate.sound.instrument:playNote(frequency, \[vel\], \[length\], \[when\])

Plays the given note on the instrument. A string like `Db3` can be used instead of a pitch/note number. Fractional values are allowed. _vel_ defaults to 1.0, fully on. If _length_ isn’t specified, the note stays on until _instrument.noteOff(note)_ is called. _when_ is the number of seconds in the future to start playing the note, default is immediately.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.playMIDINote "Link to this")

playdate.sound.instrument:playMIDINote(note, \[vel\], \[length\], \[when\])

Identical to `instrument:playNote()` but _note_ is a MIDI note number: 60=C4, 61=C#4, etc. Fractional values are allowed.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.noteOff "Link to this")

playdate.sound.instrument:noteOff(note, \[when\])

Stops the instrument voice playing note _note_. If _when_ is given, the note is stopped _when_ seconds in the future, otherwise it’s stopped immediately.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.allNotesOff "Link to this")

playdate.sound.instrument:allNotesOff()

Sends a stop signal to all playing notes.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.setVolume "Link to this")

playdate.sound.instrument:setVolume(left, \[right\])

Sets the instrument volume. If a single value is passed in, sets both left side and right side volume to the given value. If two values are given, volumes are set separately.

Volume values are between 0.0 and 1.0.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.instrument.getVolume "Link to this")

playdate.sound.instrument:getVolume()

Returns the current volume for the synth, a single value for mono sources or a pair of values (left, right) for stereo sources.

Volume values are between 0.0 and 1.0.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.controlsignal "Link to this") Control Signal

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.controlsignal.new "Link to this")

playdate.sound.controlsignal.new()

Creates a new control signal object, for automating effect parameters, channel pan and level, etc.

[Link to this](http://sdk.play.date/inside-playdate/#v-sound.controlsignal.events "Link to this")

playdate.sound.controlsignal.events

The signal’s event list is modified by getting and setting the `events` property of the object. This is an array of tables, each containing values for keys `step` and `value`, and optionally `interpolate`.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.controlsignal.addEvent2 "Link to this")

playdate.sound.controlsignal:addEvent(step, value, \[interpolate\])

playdate.sound.controlsignal:addEvent(event)

`addEvent` is a simpler way of adding events one at a time than setting the entire _events_ table. Arguments are either the values themselves in the given order, or a table containing values for `step`, `value`, and optionally `interpolate`. If `interpolate` is set, the signal’s output value is linearly interpolated from `value` at step `step` to the next event’s value at its given step.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.controlsignal.clearEvents "Link to this")

playdate.sound.controlsignal:clearEvents()

Clears all events from the control signal.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.controlsignal.setControllerType "Link to this")

playdate.sound.controlsignal:setControllerType(number)

Sets the midi controller number for the control signal, if that’s something you want to do. The value has no effect on playback.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.controlsignal.getControllerType "Link to this")

playdate.sound.controlsignal:getControllerType()

Control signals in midi files are assigned a controller number, which describes the intent of the control. This function returns the controller number.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.controlsignal.setScale "Link to this")

playdate.sound.controlsignal:setScale(scale)

Sets the scale value for the control signal.

[Link to this](http://sdk.play.date/inside-playdate/#m-sound.controlsignal.setOffset "Link to this")

playdate.sound.controlsignal:setOffset(offset)

Sets the offset value for the control signal.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.controlsignal.getValue "Link to this")

playdate.sound.controlsignal:getValue()

Returns the current output value of the control signal.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_mic_input "Link to this") Mic Input

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.micinput.recordToSample "Link to this")

playdate.sound.micinput.recordToSample(buffer, completionCallback)

`buffer` should be a [Sample](http://sdk.play.date#C-sound.sample) created with the following code, with _secondsToRecord_ replaced by a number specifying the record duration:

```
local buffer = playdate.sound.sample.new(_secondsToRecord_, playdate.sound.kFormat16bitMono)
```

`completionCallback` is a function called at the end of recording, when the buffer is full. It has one argument, the recorded sample. To override the device’s headset detection and force recording from either the internal mic or a headset mic or line in connected to a headset splitter, first call [playdate.sound.micinput.startListening()](http://sdk.play.date#f-sound.micinput.startListening) with the required source. `recordToSample()` returns `true` on success, `false` on error.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.micinput.stopRecording "Link to this")

playdate.sound.micinput.stopRecording()

Stops a sample recording started with recordToSample, if it hasn’t already reached the end of the buffer. The recording’s completion callback is called immediately.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.micinput.startListening "Link to this")

playdate.sound.micinput.startListening(\[source\])

Starts monitoring the microphone input level. The optional _source_ argument of "headset" or "device" causes the mic input to record from the given source. If no source is given, it uses the headset detection circuit to determine which source to use. The function returns the pair `true` and a string indicating which source it’s recording from on success, or `false` on error.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.micinput.stopListening "Link to this")

playdate.sound.micinput.stopListening()

Stops monitoring the microphone input level.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.micinput.getLevel "Link to this")

playdate.sound.micinput.getLevel()

Returns the current microphone input level, a value from 0.0 (quietest) to 1.0 (loudest).

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.micinput.getSource "Link to this")

playdate.sound.micinput.getSource()

Returns the current microphone input source, either "headset" or "device".

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.output "Link to this") Audio Output

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.getHeadphoneState "Link to this")

playdate.sound.getHeadphoneState(changeCallback)

Returns a pair of booleans (headphone, mic) indicating whether headphones are plugged in, and if so whether they have a microphone attached. If _changeCallback_ is a function, it will be called every time the headphone state changes, until it is cleared by calling `playdate.sound.getHeadphoneState(nil)`. If a change callback is set, the audio does **not** automatically switch from speaker to headphones when headphones are plugged in (and vice versa), so the callback should use `playdate.sound.setOutputsActive()` to change the output if needed. The callback is passed two booleans, matching the return values from `getHeadphoneState()`: the first `true` if headphones are connect, and the second `true` if the headphones have a microphone.

Equivalent to [`playdate->sound->getHeadphoneState()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-sound.getHeadphoneState) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.setOutputsActive "Link to this")

playdate.sound.setOutputsActive(headphones, speaker)

Forces sound to be played on the headphones or on the speaker, regardless of whether headphones are plugged in or not. (With the caveat that it is not actually possible to play on the headphones if they’re not plugged in.) This function has no effect in the Simulator.

Equivalent to [`playdate->sound->setOutputsActive()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-sound.setOutputsActive) in the C API.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-sound.time "Link to this") Audio Device Time

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.getCurrentTime "Link to this")

playdate.sound.getCurrentTime()

Returns the current time, in seconds, as measured by the audio device. The audio device uses its own time base in order to provide accurate timing.

Equivalent to [`playdate->sound->getCurrentTime()`](http://sdk.play.date/./Inside%20Playdate%20with%20C.html#f-sound.getCurrentTime) in the C API.

[Link to this](http://sdk.play.date/inside-playdate/#f-sound.resetTime "Link to this")

playdate.sound.resetTime()

Resets the audio output device time counter.

### [Link to this](http://sdk.play.date/inside-playdate/\#C-string "Link to this") 7.29. Strings

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/string_ to use these functions. |

[Link to this](http://sdk.play.date/inside-playdate/#f-string.UUID "Link to this")

playdate.string.UUID(length)

Generates a random string of uppercase letters

[Link to this](http://sdk.play.date/inside-playdate/#f-string.trimWhitespace "Link to this")

playdate.string.trimWhitespace(string)

Returns a string with the whitespace removed from the beginning and ending of _string_.

[Link to this](http://sdk.play.date/inside-playdate/#f-string.trimLeadingWhitespace "Link to this")

playdate.string.trimLeadingWhitespace(string)

Returns a string with the whitespace removed from the beginning of _string_.

[Link to this](http://sdk.play.date/inside-playdate/#f-string.trimTrailingWhitespace "Link to this")

playdate.string.trimTrailingWhitespace(string)

Returns a string with the whitespace removed from the ending of _string_.

### [Link to this](http://sdk.play.date/inside-playdate/\#C-timer "Link to this") 7.30. Timers

playdate.timer provides a time-based timer useful for handling animation timings, countdowns, or performing tasks after a delay. For a frame-based timer see [playdate.frameTimer](http://sdk.play.date#C-frameTimer).

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/timer_ to use these functions. It is _also_ to critical to call [playdate.timer.updateTimers()](http://sdk.play.date#f-timer.updateTimers) in your [playdate.update()](http://sdk.play.date#c-update) function to ensure that all timers are updated every frame. |

[Link to this](http://sdk.play.date/inside-playdate/#f-timer.updateTimers "Link to this")

playdate.timer.updateTimers()

This should be called from the main playdate.update() loop to drive the timers.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_standard_timers "Link to this") Standard timers

[Link to this](http://sdk.play.date/inside-playdate/#f-timer.new "Link to this")

playdate.timer.new(duration, callback, ...)

Returns a new playdate.timer that will run for _duration_ milliseconds. _callback_ is a function closure that will be called when the timer is complete.

Accepts a variable number of arguments that will be passed to the callback function when it is called. If arguments are not provided, the timer itself will be passed to the callback instead.

By default, timers start upon instantiation. To modify the behavior of a timer, see [common timer methods](http://sdk.play.date#C-commonTimerMethods) and [properties](http://sdk.play.date#C-commonTimerProperties).

#### [Link to this](http://sdk.play.date/inside-playdate/\#_delay_timers "Link to this") Delay timers

[Link to this](http://sdk.play.date/inside-playdate/#f-timer.performAfterDelay "Link to this")

playdate.timer.performAfterDelay(delay, callback, ...)

Performs the function _callback_ after _delay_ milliseconds. Accepts a variable number of arguments that will be passed to the callback function when it is called. If arguments are not provided, the timer itself will be passed to the callback instead.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_value_timers "Link to this") Value timers

[Link to this](http://sdk.play.date/inside-playdate/#f-timer.new2 "Link to this")

playdate.timer.new(duration, \[startValue, endValue, \[easingFunction\]\])

Returns a new playdate.timer that will run for _duration_ milliseconds. If not specified, _startValue_ and _endValue_ will be 0, and a linear easing function will be used.

By default, timers start upon instantiation. To modify the behavior of a timer, see [common timer methods](http://sdk.play.date#C-commonTimerMethods) and [properties](http://sdk.play.date#C-commonTimerProperties).

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.value "Link to this")

playdate.timer.value

Current value calculated from the start and end values, the time elapsed, and the easing function.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.easingFunction "Link to this")

playdate.timer.easingFunction

The function used to calculate _value_. The function should be of the form _function(t, b, c, d)_, where _t_ is elapsed time, _b_ is the beginning value, _c_ is the change (or end value - start value), and _d_ is the duration. Many such functions are available in [playdate.easingFunctions](http://sdk.play.date#M-easingFunctions).

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.reverseEasingFunction "Link to this")

playdate.timer.reverseEasingFunction

Set to provide an easing function to be used for the reverse portion of the timer. The function should be of the form _function(t, b, c, d)_, where _t_ is elapsed time, _b_ is the beginning value, _c_ is the change (or end value - start value), and _d_ is the duration. Many such functions are available in [playdate.easingFunctions](http://sdk.play.date#M-easingFunctions).

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.startValue "Link to this")

playdate.timer.startValue

Start value used when calculating _value_.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.endValue "Link to this")

playdate.timer.endValue

End value used when calculating _value_.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_key_repeat_timers "Link to this") Key repeat timers

[Link to this](http://sdk.play.date/inside-playdate/#f-timer.keyRepeatTimer "Link to this")

playdate.timer.keyRepeatTimer(callback, ...)

Calls `keyRepeatTimerWithDelay()` below with standard values of _delayAfterInitialFiring_ = 300 and _delayAfterSecondFiring_ = 100.

[Link to this](http://sdk.play.date/inside-playdate/#f-timer.keyRepeatTimerWithDelay "Link to this")

playdate.timer.keyRepeatTimerWithDelay(delayAfterInitialFiring, delayAfterSecondFiring, callback, ...)

returns a timer that fires at key-repeat intervals. The function _callback_ will be called immediately, then again after _delayAfterInitialFiring_ milliseconds, then repeatedly at _delayAfterSecondFiring_ millisecond intervals.

Both functions accept any number of arguments; those arguments will be passed to the callback function when it is called. If arguments are not provided, the timer itself will be passed instead.

Sample keyRepeatTimer callback

```
import "CoreLibs/timer"

local keyTimer = nil

function playdate.BButtonDown()
    local function timerCallback()
        print("key repeat timer fired!")
    end
    keyTimer = playdate.timer.keyRepeatTimer(timerCallback)
end

function playdate.BButtonUp()
    keyTimer:remove()
end

function playdate.update()
    playdate.timer.updateTimers()
end
```

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-commonTimerMethods "Link to this") Common timer methods

[Link to this](http://sdk.play.date/inside-playdate/#m-timer.pause "Link to this")

playdate.timer:pause()

Pauses a timer. (There is no need to call :start() on a newly-instantiated timer: timers start automatically.)

[Link to this](http://sdk.play.date/inside-playdate/#m-timer.start "Link to this")

playdate.timer:start()

Resumes a previously paused timer. There is no need to call :start() on a newly-instantiated timer: timers start automatically.

[Link to this](http://sdk.play.date/inside-playdate/#m-timer.remove "Link to this")

playdate.timer:remove()

Removes this timer from the list of timers. This happens automatically when a non-repeating timer reaches its end, but you can use this method to dispose of timers manually.

Note that timers do not actually get removed until the next invocation of [playdate.timer.updateTimers()](http://sdk.play.date#f-timer.updateTimers).

[Link to this](http://sdk.play.date/inside-playdate/#m-timer.reset "Link to this")

playdate.timer:reset()

Resets a timer to its initial values.

[Link to this](http://sdk.play.date/inside-playdate/#f-timer.allTimers "Link to this")

playdate.timer.allTimers()

Returns an array listing all running timers.

|     |     |
| --- | --- |
| Note | Note the "." syntax rather than ":". This is a class method, not an instance method. |

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-commonTimerProperties "Link to this") Common timer properties

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.currentTime "Link to this")

playdate.timer.currentTime

The number of milliseconds the timer has been running. Read-only.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.delay "Link to this")

playdate.timer.delay

Number of milliseconds to wait before starting the timer.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.discardOnCompletion "Link to this")

playdate.timer.discardOnCompletion

If true, the timer is discarded once it is complete. Defaults to true.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.duration "Link to this")

playdate.timer.duration

The number of milliseconds for which the timer will run.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.timeLeft "Link to this")

playdate.timer.timeLeft

The number of milliseconds remaining in the timer. Read-only.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.paused "Link to this")

playdate.timer.paused

If true, the timer will be paused. The update callback will not be called when the timer is paused. Can be set directly, or by using `playdate.timer:pause()` and `playdate.timer:start()`. Defaults to false.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.repeats "Link to this")

playdate.timer.repeats

If true, the timer starts over from the beginning when it completes. Defaults to false.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.reverses "Link to this")

playdate.timer.reverses

If true, the timer plays in reverse once it has completed. The time to complete both the forward and reverse will be _duration_ x 2. Defaults to false.

Please note that _currentTime_ will restart at 0 and count up to _duration_ again when the reverse timer starts, but _value_ will be calculated in reverse, from _endValue_ to _startValue_. The same easing function (as opposed to the inverse of the easing function) will be used for the reverse timer unless an alternate is provided by setting _reverseEasingFunction_.

[Link to this](http://sdk.play.date/inside-playdate/#c-timer.timerEndedCallback "Link to this")

playdate.timer.timerEndedCallback

A Function of the form _function(timer)_ or _function(...)_ where "..." corresponds to the values in the table assigned to _timerEndedArgs_. Called when the timer has completed.

[Link to this](http://sdk.play.date/inside-playdate/#v-timer.timerEndedArgs "Link to this")

playdate.timer.timerEndedArgs

For repeating timers, this function will be called each time the timer completes, before it starts again.

An array-style table of values that will be passed to the _timerEndedCallback_ function.

[Link to this](http://sdk.play.date/inside-playdate/#c-timer.updateCallback "Link to this")

playdate.timer.updateCallback

A callback function that will be called on every frame (every time _timer.updateAll()_ is called). If the timer was created with arguments, those will be passed as arguments to the function provided. Otherwise, the timer is passed as the single argument.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_timer_sample_code "Link to this") Timer sample code

To count milliseconds, a simple timer can be created as follows:

```
t = playdate.timer.new(1000)
```

The timer will begin running immediately. The current time can be read by looking at _t.currentTime_.

To transition between two values, set up a timer like:

```
t = timer(500, 0, 100)
```

If no easing function is provided as a fourth argument linear easing will be used. As the timer runs, you can access the current value by looking at _t.value_.

In both of these examples, the timer will be automatically discarded once it is finished. Set _discardOnCompletion_ to false to keep the timer around for later reuse.

An example of setting up a bouncing ball animation (assuming the ball would be drawn elsewhere based on the rectangle _r_):

```
local r = playdate.geometry.rect.new(100, 10, 40, 40)
```

```
local t = playdate.timer.new(1000, 10, 150, easingFunctions.inCubic)
t.reverses = true
t.repeats = true
t.reverseEasingFunction = easingFunctions.outQuad
t.updateCallback = function(timer)
	r.y = timer.value
end
```

### [Link to this](http://sdk.play.date/inside-playdate/\#C-frameTimer "Link to this") 7.31. Frame timers

A frame-based timer useful for handling frame-precise animation timings. For a time-based timer see [playdate.timer](http://sdk.play.date#C-timer) or [playdate.graphics.animation.loop](http://sdk.play.date#C-graphics.animation.loop)

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/frameTimer_ to use these functions. It is _also_ to critical to call [playdate.frameTimer.updateTimers()](http://sdk.play.date#f-timer.updateTimers) in your [playdate.update()](http://sdk.play.date#c-update) function to ensure that all timers are updated every frame. |

[Link to this](http://sdk.play.date/inside-playdate/#f-frameTimer.updateTimers "Link to this")

playdate.frameTimer.updateTimers()

This should be called from the main playdate.update() loop to drive the frame timers.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_standard_frame_timers "Link to this") Standard frame timers

[Link to this](http://sdk.play.date/inside-playdate/#f-frameTimer.new "Link to this")

playdate.frameTimer.new(duration, callback, ...)

Returns a new playdate.frameTimer that will run for _duration_ frames. _callback_ is a function closure that will be called when the timer is complete.

Accepts a variable number of arguments that will be passed to the callback function when it is called. If arguments are not provided, the timer itself will be passed to the callback instead.

By default, frame timers start upon instantiation. To modify the behavior of a frame timer, see [common frame timer methods](http://sdk.play.date#C-commonFrameTimerMethods) and [properties](http://sdk.play.date#C-commonFrameTimerProperties).

#### [Link to this](http://sdk.play.date/inside-playdate/\#_delay_frame_timers "Link to this") Delay frame timers

[Link to this](http://sdk.play.date/inside-playdate/#f-frameTimer.performAfterDelay "Link to this")

playdate.frameTimer.performAfterDelay(delay, callback, ...)

Performs the function _callback_ after the _delay_ number of frames. Accepts a variable number of arguments that will be passed to the callback function when it is called. If arguments are not provided, the timer itself will be passed to the callback instead.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_value_frame_timers "Link to this") Value frame timers

[Link to this](http://sdk.play.date/inside-playdate/#f-frameTimer.new-value "Link to this")

playdate.frameTimer.new(duration, \[startValue, endValue, \[easingFunction\]\])

Returns a new playdate.frameTimer that will run for _duration_ number of frames. If not specified, _startValue_ and _endValue_ will be 0, and a linear easing function will be used.

By default, frame timers start upon instantiation. To modify the behavior of a frame timer, see [common frame timer methods](http://sdk.play.date#C-commonFrameTimerMethods) and [properties](http://sdk.play.date#C-commonFrameTimerProperties).

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.value "Link to this")

playdate.frameTimer.value

Current value calculated from the start and end values, the current frame, and the easing function.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.startValue "Link to this")

playdate.frameTimer.startValue

Start value used when calculating _value_.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.endValue "Link to this")

playdate.frameTimer.endValue

End value used when calculating _value_.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.easingFunction "Link to this")

playdate.frameTimer.easingFunction

The function used to calculate _value_. The function should be of the form _function(t, b, c, d)_, where _t_ is elapsed time, _b_ is the beginning value, _c_ is the change (or _endValue - startValue_), and _d_ is the duration.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.easingAmplitude "Link to this")

playdate.frameTimer.easingAmplitude

playdate.frameTimer.easingPeriod

For easing functions in _CoreLibs/easing_ that take additional amplitude and period arguments (such as _inOutElastic_), set these to desired values.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.reverseEasingFunction "Link to this")

playdate.frameTimer.reverseEasingFunction

Set to provide an easing function to be used for the reverse portion of the timer. The function should be of the form _function(t, b, c, d)_, where _t_ is elapsed time, _b_ is the beginning value, _c_ is the change (or _endValue - startValue_), and _d_ is the duration.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-commonFrameTimerMethods "Link to this") Common frame timer methods

[Link to this](http://sdk.play.date/inside-playdate/#m-frameTimer.pause "Link to this")

playdate.frameTimer:pause()

Pauses a timer.

[Link to this](http://sdk.play.date/inside-playdate/#m-frameTimer.start "Link to this")

playdate.frameTimer:start()

Resumes a timer. There is no need to call :start() on a newly-instantiated frame timer: frame timers start automatically.

[Link to this](http://sdk.play.date/inside-playdate/#m-frameTimer.remove "Link to this")

playdate.frameTimer:remove()

Removes this timer from the list of timers. This happens automatically when a non-repeating timer reaches it’s end, but you can use this method to dispose of timers manually.

[Link to this](http://sdk.play.date/inside-playdate/#m-frameTimer.reset "Link to this")

playdate.frameTimer:reset()

Resets a timer to its initial values.

[Link to this](http://sdk.play.date/inside-playdate/#f-frameTimer.allTimers "Link to this")

playdate.frameTimer.allTimers()

Returns an array listing all running frameTimers.

|     |     |
| --- | --- |
| Note | Note the "." syntax rather than ":". This is a class method, not an instance method. |

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-commonFrameTimerProperties "Link to this") Common frame timer properties

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.delay "Link to this")

playdate.frameTimer.delay

Number of frames to wait before starting the timer.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.discardOnCompletion "Link to this")

playdate.frameTimer.discardOnCompletion

If true, the timer is discarded once it is complete. Defaults to true.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.duration "Link to this")

playdate.frameTimer.duration

The number of frames for which the timer will run.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.frame "Link to this")

playdate.frameTimer.frame

The current frame.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.repeats "Link to this")

playdate.frameTimer.repeats

If true, the timer starts over from the beginning when it completes. Defaults to false.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.reverses "Link to this")

playdate.frameTimer.reverses

If true, the timer plays in reverse once it has completed. The number of frames to complete both the forward and reverse will be _duration x 2_. Defaults to false.

Please note that the frame counter will restart at 0 and count up to _duration_ again when the reverse timer starts, but _value_ will be calculated in reverse, from _endValue_ to _startValue_. The same easing function (as opposed to the inverse of the easing function) will be used for the reverse timer unless an alternate is provided by setting _reverseEasingFunction_.

[Link to this](http://sdk.play.date/inside-playdate/#c-frameTimer.timerEndedCallback "Link to this")

playdate.frameTimer.timerEndedCallback

A Function of the form _function(timer)_ or _function(...)_ where "..." corresponds to the values in the table assigned to _timerEndedArgs_. Called when the timer has completed.

[Link to this](http://sdk.play.date/inside-playdate/#v-frameTimer.timerEndedArgs "Link to this")

playdate.frameTimer.timerEndedArgs

For repeating timers, this function will be called each time the timer completes, before it starts again.

An array-style table of values that will be passed to the _timerEndedCallback_ function.

[Link to this](http://sdk.play.date/inside-playdate/#c-frameTimer.updateCallback "Link to this")

playdate.frameTimer.updateCallback

A function to be called on every frame update. If the frame timer was created with arguments, those will be passed as arguments to the function provided. Otherwise, the timer is passed as the single argument.

#### [Link to this](http://sdk.play.date/inside-playdate/\#_frame_timer_sample_code "Link to this") Frame timer sample code

To count frames a simple timer can be created as follows:

```
t = playdate.frameTimer.new(200)
```

The timer will begin running immediately, and the current frame can be read by looking at _t.frame_.

To transition between two values, set up a timer like:

```
t = FrameTimer(50, 0, 100)
```

If no easing function is provided as a fourth argument linear easing will be used. As the timer runs, you can access the current value by looking at _t.value_.

In both of these examples, the timer will be automatically discarded once it is finished. Set _discardOnCompletion_ to false to keep the timer around for later reuse.

An example of setting up a bouncing ball animation (assuming the ball would be drawn elsewhere based on the rectangle _r_):

```
local r = playdate.geometry.rect.new(100, 10, 40, 40)

local t = playdate.frameTimer.new(20, 10, 150, playdate.easingFunctions.inCubic)
t.reverses = true
t.repeats = true
t.reverseEasingFunction = playdate.easingFunctions.outQuad
t.updateCallback = function(timer)
    r.y = timer.value
end
```

### [Link to this](http://sdk.play.date/inside-playdate/\#M-ui "Link to this") 7.32. UI components

playdate.ui provides common UI elements for playdate games.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-ui.crankIndicator "Link to this") Crank indicator

`playdate.ui.crankIndicator` is used to draw a standard indicator at the lower right corner of the screen that directs the player to use the crank.

As your game calls [`playdate.ui.crankIndicator:draw()`](http://sdk.play.date#m-ui.crankIndicator.draw) on successive frames, the Playdate screen will display a "Use the Crank" message for ~0.7 seconds, then an animation of a rotating crank for ~1.4 seconds. (The direction of animation is specified by [`.clockwise`](http://sdk.play.date#v-ui.crankIndicator.clockwise).)

In some situations you may only want to alert the player to "use the crank" if [`playdate.isCrankDocked()`](http://sdk.play.date#f-isCrankDocked) returns `true`, indicating that the crank is not extended.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/ui_ to use crankIndicator. There is no need to instantiate a crankIndicator object; `playdate.ui.crankIndicator` automatically returns the shared crankIndicator instance. |

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.crankIndicator.draw "Link to this")

playdate.ui.crankIndicator:draw(\[xOffset, yOffset\])

Draws the next frame of the crank indicator animation, and is typically invoked in the [`playdate.update()`](http://sdk.play.date#c-update) callback. _xOffset_ and _yOffset_ can be used to alter the position of the indicator by a specified number of pixels if desired. To stop drawing the crank indicator, simply stop calling `:draw()` in `playdate.update()`.

Note that if sprites are being used, this call should usually happen after [playdate.graphics.sprite.update()](http://sdk.play.date#f-graphics.sprite.update).

[Link to this](http://sdk.play.date/inside-playdate/#v-ui.crankIndicator.clockwise "Link to this")

playdate.ui.crankIndicator.clockwise

Boolean property specifying which direction to animate the crank. Defaults to true.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.crankIndicator.reset "Link to this")

playdate.ui.crankIndicator:resetAnimation()

Resets the crank animation to the beginning of its sequence.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.crankIndicator.getBounds "Link to this")

playdate.ui.crankIndicator:getBounds()

Returns _x_, _y_, _width_, _height_ representing the bounds that the crank indicator draws within. If necessary, this rect could be passed into [playdate.graphics.sprite.addDirtyRect()](http://sdk.play.date#m-graphics.sprite.addDirtyRect), or used to manually draw over the indicator image drawn by [playdate.ui.crankIndicator:draw()](http://sdk.play.date#m-crankIndicator.draw) when you want to stop showing the crank indicator.

#### [Link to this](http://sdk.play.date/inside-playdate/\#C-ui.gridview "Link to this") Grid view

playdate.ui.gridview provides a means for drawing a grid view composed of cells, and optionally sections with section headers.

|     |     |
| --- | --- |
| Important | You must import _CoreLibs/ui_ to use gridview. |

Some notes:

- playdate.ui.gridview uses [playdate.timer](http://sdk.play.date#C-timer) internally, so [playdate.timer.updateTimers()](http://sdk.play.date#f-timer.updateTimers) must be called in the main [playdate.update()](http://sdk.play.date#c-update) function.

- If the gridview’s cell width is set to 0, cells will be drawn the same width as the table (minus any padding).

- Section headers always draw the full width of the grid (minus padding), and do not scroll horizontally along with the rest of the content.


[Link to this](http://sdk.play.date/inside-playdate/#f-ui.gridview.new "Link to this")

playdate.ui.gridview.new(cellWidth, cellHeight)

Returns a new [playdate.ui.gridview](http://sdk.play.date#C-ui.gridview) with cells sized _cellWidth_, _cellHeight_. (Sizes are in pixels.) If cells should span the entire width of the grid (as in a list view), pass zero (0) for _cellWidth_.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_drawing_4 "Link to this") Drawing

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.drawCell "Link to this")

playdate.ui.gridview:drawCell(section, row, column, selected, x, y, width, height)

Override this method to draw the cells in the gridview. _selected_ is a boolean, true if the cell being drawn is the currently-selected cell.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.drawSectionHeader "Link to this")

playdate.ui.gridview:drawSectionHeader(section, x, y, width, height)

Override this method to draw section headers. This function will only be called if the header height has been set to a value greater than zero (0).

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.drawHorizontalDivider "Link to this")

playdate.ui.gridview:drawHorizontalDivider(x, y, width, height)

Override this method to customize the drawing of horizontal dividers. This function will only be called if the horizontal divider height is greater than zero (0) and at least one divider has been added.

[Link to this](http://sdk.play.date/inside-playdate/#v-ui.gridview.needsDisplay "Link to this")

playdate.ui.gridview.needsDisplay

This read-only variable returns true if the gridview needs to be redrawn. This can be used to help optimize drawing in your app. Keep in mind that a gridview cannot know all reasons it may need to be redrawn, such as changes in your drawing callback functions, coordinate or size changes, or overlapping drawing, so you may need to additionally redraw at other times.

Conditionally draw a grid view

```
if myGridView.needsDisplay == true then
    myGridView:drawInRect(x, y, w, h)
end
```

##### [Link to this](http://sdk.play.date/inside-playdate/\#_configuration "Link to this") Configuration

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setNumberOfSections "Link to this")

playdate.ui.gridview:setNumberOfSections(num)

Sets the number of sections in the grid view. Each section contains at least one row, and row numbering starts at 1 in each section.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.getNumberOfSections "Link to this")

playdate.ui.gridview:getNumberOfSections()

Returns the number of sections in the grid view.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setNumberOfRowsInSection "Link to this")

playdate.ui.gridview:setNumberOfRowsInSection(section, num)

Sets the number of rows in _section_.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.getNumberOfRowsInSection "Link to this")

playdate.ui.gridview:getNumberOfRowsInSection(section)

Returns the number of rows in _section_.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setNumberOfColumns "Link to this")

playdate.ui.gridview:setNumberOfColumns(num)

Sets the number of columns in the gridview. 1 by default.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.getNumberOfColumns "Link to this")

playdate.ui.gridview:getNumberOfColumns()

Returns the number of columns in the gridview. 1 by default.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setNumberOfRows "Link to this")

playdate.ui.gridview:setNumberOfRows(…​)

Convenience method for list-style gridviews, or for setting the number of rows for multiple sections at a time. Pass in a list of numbers of rows for sections starting from section 1.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setCellSize "Link to this")

playdate.ui.gridview:setCellSize(cellWidth, cellHeight)

Sets the size of the cells in the gridview. If cells should span the entire width of the grid (as in a list view), pass zero (0) for _cellWidth_.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setCellPadding "Link to this")

playdate.ui.gridview:setCellPadding(left, right, top, bottom)

Sets the amount of padding around cells.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setContentInset "Link to this")

playdate.ui.gridview:setContentInset(left, right, top, bottom)

Sets the amount of space the content is inset from the edges of the gridview. Useful if a background image is being used as a border.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.getCellBounds "Link to this")

playdate.ui.gridview:getCellBounds(section, row, column, \[gridWidth\])

Returns multiple values (x, y, width, height) representing the bounds of the cell, not including padding, relative to the top-right corner of the grid view.

If the grid view is configured with zero width cells (see [playdate.ui.gridview:new](http://sdk.play.date#f-gridview.new)), _gridWidth_ is required, and should be the same value you would pass to [playdate.ui.gridview:drawInRect](http://sdk.play.date#m-gridview.drawInRect).

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setSectionHeaderHeight "Link to this")

playdate.ui.gridview:setSectionHeaderHeight(height)

Sets the height of the section headers. 0 by default, which causes section headers not to be drawn.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.getSectionHeaderHeight "Link to this")

playdate.ui.gridview.getSectionHeaderHeight()

Returns the current height of the section headers.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setSectionHeaderPadding "Link to this")

playdate.ui.gridview:setSectionHeaderPadding(left, right, top, bottom)

Sets the amount of padding around section headers.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setHorizontalDividerHeight "Link to this")

playdate.ui.gridview:setHorizontalDividerHeight(height)

Sets the height of the horizontal dividers. The default height is half the cell height specified when creating the grid view.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.getHorizontalDividerHeight "Link to this")

playdate.ui.gridview:getHorizontalDividerHeight()

Returns the height of the horizontal dividers.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.addHorizontalDividerAbove "Link to this")

playdate.ui.gridview:addHorizontalDividerAbove(section, row)

Causes a horizontal divider to be drawn above the specified row. Drawing can be customized by overriding [playdate.ui.gridview:drawHorizontalDivider](http://sdk.play.date#m-gridview.drawHorizontalDivider).

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.removeHorizontalDividers "Link to this")

playdate.ui.gridview:removeHorizontalDividers()

Removes all horizontal dividers from the grid view.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_scrolling_2 "Link to this") Scrolling

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setScrollDuration "Link to this")

playdate.ui.gridview:setScrollDuration(ms)

Controls the duration of scroll animations. 250ms by default.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setScrollPosition "Link to this")

playdate.ui.gridview:setScrollPosition(x, y, \[animated\])

'set' scrolls to the coordinate _x_, _y_.

If _animated_ is true (or not provided) the new scroll position is animated to using [playdate.ui.gridview.scrollEasingFunction](http://sdk.play.date#v-gridview.scrollEasingFunction) and the value set in [playdate.ui.gridview:setScrollDuration()](http://sdk.play.date#m-gridview.setScrollDuration).

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.getScrollPosition "Link to this")

playdate.ui.gridview:getScrollPosition()

Returns the current scroll location as a pair _x_, _y_.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.scrollToCell "Link to this")

playdate.ui.gridview:scrollToCell(section, row, column, \[animated\])

Scrolls to the specified cell, just enough so the cell is visible.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.scrollCellToCenter "Link to this")

playdate.ui.gridview:scrollCellToCenter(section, row, column, \[animated\])

Scrolls to the specified cell, so the cell is centered in the gridview, if possible.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.scrollToRow "Link to this")

playdate.ui.gridview:scrollToRow(row, \[animated\])

Convenience function for list-style gridviews. Scrolls to the specified row in the list.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.scrollToTop "Link to this")

playdate.ui.gridview:scrollToTop(\[animated\])

Scrolls to the top of the gridview.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_selection "Link to this") Selection

Changing the selection can also change the scroll position. By default cells are scrolled so that they are centered in the gridview, if possible. To change that behavior so the grid is just scrolled enough to make the cell visible, set [scrollCellsToCenter](http://sdk.play.date#v-gridview.scrollCellsToCenter) to false.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setSelection "Link to this")

playdate.ui.gridview:setSelection(section, row, column)

Selects the cell at the given position.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.getSelection "Link to this")

playdate.ui.gridview:getSelection()

Returns the currently-selected cell as _section_, _row_, _column_

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.setSelectedRow "Link to this")

playdate.ui.gridview:setSelectedRow(row)

Convenience method for list-style gridviews. Selects the cell at _row_ in section 1.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.getSelectedRow "Link to this")

playdate.ui.gridview:getSelectedRow()

Convenience method for list-style gridviews. Returns the selected cell at _row_ in section 1.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.selectNextRow "Link to this")

playdate.ui.gridview:selectNextRow(wrapSelection, \[scrollToSelection, animate\])

Selects the cell directly below the currently-selected cell.

If _wrapSelection_ is true, the selection will wrap around to the opposite end of the grid. If _scrollToSelection_ is true (or not provided), the newly-selected cell will be scrolled to. If _animate_ is true (or not provided), the scroll will be animated.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.selectPreviousRow "Link to this")

playdate.ui.gridview:selectPreviousRow(wrapSelection, \[scrollToSelection, animate\])

Identical to `selectNextRow()` but goes the other direction.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.selectNextColumn "Link to this")

playdate.ui.gridview:selectNextColumn(wrapSelection, \[scrollToSelection, animate\])

Selects the cell directly to the right of the currently-selected cell.

If the last column is currently selected and _wrapSelection_ is true, the selection will wrap around to the opposite side of the grid. If a wrap occurs and the gridview’s [`changeRowOnColumnWrap`](http://sdk.play.date#v-gridview.changeRowOnColumnWrap) is `true` the row will also be advanced or moved back.

If _scrollToSelection_ is true (or not provided), the newly-selected cell will be scrolled to. If _animate_ is true (or not provided), the scroll will be animated.

[Link to this](http://sdk.play.date/inside-playdate/#m-ui.gridview.selectPreviousColumn "Link to this")

playdate.ui.gridview:selectPreviousColumn(wrapSelection, \[scrollToSelection, animate\])

Identical to `selectNextColumn()` but goes the other direction.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_properties "Link to this") Properties

[Link to this](http://sdk.play.date/inside-playdate/#v-ui.gridview.backgroundImage "Link to this")

playdate.ui.gridview.backgroundImage

A background image that draws behind the gridview’s cells. This image can be either a [`playdate.graphics.image`](http://sdk.play.date#C-graphics.image) which will be tiled or a [`playdate.nineSlice`](http://sdk.play.date#C-graphics.nineSlice).

[Link to this](http://sdk.play.date/inside-playdate/#v-ui.gridview.isScrolling "Link to this")

playdate.ui.gridview.isScrolling

Read-only. True if the gridview is currently performing a scroll animation.

[Link to this](http://sdk.play.date/inside-playdate/#v-ui.gridview.scrollEasingFunction "Link to this")

playdate.ui.gridview.scrollEasingFunction

The easing function used when performing scroll animations. The function should be of the form function(t, b, c, d), where t is elapsed time, b is the beginning value, c is the change, or end value - start value, and d is the duration. Many such functions are available in [`playdate.easingFunctions`](http://sdk.play.date#M-easingFunctions). [`playdate.easingFunctions.outCubic`](http://sdk.play.date#f-easingFunctions.outCubic) is the default.

[Link to this](http://sdk.play.date/inside-playdate/#v-ui.gridview.easingAmplitude "Link to this")

playdate.ui.gridview.easingAmplitude

playdate.ui.gridview.easingPeriod

For [easing functions](http://sdk.play.date#M-easingFunctions) that take additional amplitude and period arguments (such as _inOutElastic_), set these to the desired values.

[Link to this](http://sdk.play.date/inside-playdate/#v-ui.gridview.changeRowOnColumnWrap "Link to this")

playdate.ui.gridview.changeRowOnColumnWrap

Controls the behavior of [playdate.ui.gridview:selectPreviousColumn()](http://sdk.play.date#m-gridview.selectPreviousColumn) and [playdate.ui.gridview:selectNextColumn()](http://sdk.play.date#m-gridview.selectNextColumn) if the current selection is at the first or last column, respectively. If set to true, the selection switch to a new row to allow the selection to change. If false, the call will have no effect on the selection. True by default.

[Link to this](http://sdk.play.date/inside-playdate/#v-ui.gridview.scrollCellsToCenter "Link to this")

playdate.ui.gridview.scrollCellsToCenter

If true, the gridview will attempt to center cells when scrolling. If false, the gridview will be scrolled just as much as necessary to make the cell visible.

##### [Link to this](http://sdk.play.date/inside-playdate/\#_grid_view_sample_code "Link to this") Grid view sample code

To set up a grid view, specify the dimensions and override the necessary drawing methods:

Grid view example

```
local gfx = playdate.graphics
local gridview = playdate.ui.gridview.new(44, 44)
gridview.backgroundImage = playdate.graphics.nineSlice.new('shadowbox', 4, 4, 45, 45)
gridview:setNumberOfColumns(8)
gridview:setNumberOfRows(2, 4, 3, 5) -- number of sections is set automatically
gridview:setSectionHeaderHeight(24)
gridview:setContentInset(1, 4, 1, 4)
gridview:setCellPadding(4, 4, 4, 4)
gridview.changeRowOnColumnWrap = false

function gridview:drawCell(section, row, column, selected, x, y, width, height)
    if selected then
        gfx.drawCircleInRect(x-2, y-2, width+4, height+4, 3)
    else
        gfx.drawCircleInRect(x+4, y+4, width-8, height-8, 0)
    end
    local cellText = ""..row.."-"..column
    gfx.drawTextInRect(cellText, x, y+14, width, 20, nil, nil, kTextAlignment.center)
end

function gridview:drawSectionHeader(section, x, y, width, height)
    gfx.drawText("*SECTION ".. section .. "*", x + 10, y + 8)
end
```

For the simple case of a simple list-style grid:

List-style grid view example

```
local menuOptions = {"Sword", "Shield", "Arrow", "Sling", "Stone", "Longbow", "MorningStar", "Armour", "Dagger", "Rapier", "Skeggox", "War Hammer", "Battering Ram", "Catapult"}
local listview = playdate.ui.gridview.new(0, 10)
listview.backgroundImage = playdate.graphics.nineSlice.new('scrollbg', 20, 23, 92, 28)
listview:setNumberOfRows(#menuOptions)
listview:setCellPadding(0, 0, 13, 10)
listview:setContentInset(24, 24, 13, 11)

function listview:drawCell(section, row, column, selected, x, y, width, height)
        if selected then
                gfx.fillRoundRect(x, y, width, 20, 4)
                gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
        gfx.drawTextInRect(menuOptions[row], x, y+2, width, height, nil, "...", kTextAlignment.center)
end
```

Then, to draw the grid view:

Drawing a grid view

```
function playdate.update()
    gridview:drawInRect(20, 20, 180, 200)
    listview:drawInRect(220, 20, 160, 210)
    playdate.timer:updateTimers()
end
```

### [Link to this](http://sdk.play.date/inside-playdate/\#M-wired-networking "Link to this") 7.33. Serial communication

[Link to this](http://sdk.play.date/inside-playdate/#c-serialMessageReceived "Link to this")

playdate.serialMessageReceived(message)

Called when a `msg <text>` command is received on the serial port. The text following the command is passed to the function as the string _message_.

Running `!msg <message>` in the simulator Lua console sends the command to the device if one is connected, otherwise it sends it to the game running in the simulator.

### [Link to this](http://sdk.play.date/inside-playdate/\#M-mirror "Link to this") 7.34. Playdate Mirror

[Mirror](http://play.date/mirror/) is an app that routes Playdate’s audio and video to an PC running Windows, macOS, or Linux.

[Link to this](http://sdk.play.date/inside-playdate/#c-mirrorStarted "Link to this")

playdate.mirrorStarted()

Called when the device is connected to Mirror.

|     |     |
| --- | --- |
| Caution | In rare situations, Mirror may have trouble keeping up with games running at a high framerate (> 40 fps). If you find this consistently happens to your game, you can optionally use these callbacks to lower the amount of computation or drawing you do so as to give more time to Playdate OS on each frame, improving your user’s experience while playing your game via Mirror. |

[Link to this](http://sdk.play.date/inside-playdate/#c-mirrorEnded "Link to this")

playdate.mirrorEnded()

Called when the device is disconnected from Mirror.

### [Link to this](http://sdk.play.date/inside-playdate/\#M-garbage-collection "Link to this") 7.35. Garbage collection

[Link to this](http://sdk.play.date/inside-playdate/#f-setCollectsGarbage "Link to this")

playdate.setCollectsGarbage(flag)

If _flag_ is false, automatic garbage collection is disabled and the game should manually collect garbage with Lua’s `collectgarbage()` function.

[Link to this](http://sdk.play.date/inside-playdate/#f-setMinimumGCTime "Link to this")

playdate.setMinimumGCTime(ms)

Force the Lua garbage collector to run for at least _ms_ milliseconds every frame, so that garbage doesn’t pile up and cause the game to run out of memory and stall in emergency garbage collection. The default value is 1 millisecond.

|     |     |
| --- | --- |
| Tip | If your game isn’t generating a lot of garbage, it might be advantageous to set a smaller minimum GC time, granting more CPU bandwidth to your game. |

[Link to this](http://sdk.play.date/inside-playdate/#f-setGCScaling "Link to this")

playdate.setGCScaling(min, max)

When the amount of used memory is less than `min` (scaled from 0-1, as a percentage of total system memory), the system will only run the collector for the minimum GC time, as set by [playdate.setGCScaling()](http://sdk.play.date#f-setGCScaling), every frame. If the used memory is more than `max`, the system will spend all free time running the collector. Between the two, the time used by the garbage collector is scaled proportionally.

For example, if the scaling is set to a min of 0.4 and max of 0.7, and memory is half full, the collector will run for the minimum GC time plus 1/3 of whatever time is left before the next frame (because (0.5 - 0.4) / (0.7 - 0.4) = 1/3).

The default behavior is a scaling of `(0.0, 1.0)`. If set to `(0.0, 0.0)`, the system will use all available extra time each frame running GC.

The Playdate APIs include a lot of functionality you might expect:

There are also some unexpected APIs, some unique to the Playdate platform, that you may not be aware of. Be sure to take a look at these:

### [Link to this](http://sdk.play.date/inside-playdate/\#_lua_enhancements "Link to this") 8.1. Lua enhancements

The Playdate SDK offers some enhancements to standard Lua, including [additional assignment operators](http://sdk.play.date#additional-assignment-operators) ( `+=`, `-=`) and [convenience functions for handling Lua tables](http://sdk.play.date#table-additions).

### [Link to this](http://sdk.play.date/inside-playdate/\#_debugging "Link to this") 8.2. Debugging

- [playdate.drawFPS()](http://sdk.play.date#f-drawFPS): Displays the current framerate onscreen.

- [playdate.debugDraw()](http://sdk.play.date#c-debugDraw): Highlight regions on the Simulator screen in a different color, to aid in debugging.

- [printTable()](http://sdk.play.date#f-printTable): Outputs the contents of a table to the console.

- [playdate.keyPressed()](http://sdk.play.date#c-keyPressed): Captures computer keyboard keypresses as an aid in debugging. For example, typing a number might advance the game to a higher level.


### [Link to this](http://sdk.play.date/inside-playdate/\#_enhancing_your_games_user_experience "Link to this") 8.3. Enhancing your game’s user experience

- [playdate.ui.crankIndicator()](http://sdk.play.date#C-ui.crankIndicator): Inform the player that your game uses the crank.

- [playdate.menu:addOptionsMenuItem()](http://sdk.play.date#m-menu.addOptionsMenuItem): Add a special menu item for your game into the System Menu.

- [playdate.wait()](http://sdk.play.date#f-wait): Pause your game’s execution for a specified period of time. Useful for, say, suspending gameplay while displaying a message to the player.

- [playdate.setMenuImage()](http://sdk.play.date#f-setMenuImage): Set a custom image that displays on the left-side of the screen while your game is paused.

- [playdate.keyboard](http://sdk.play.date#M-keyboard): Display a special Playdate keyboard onscreen and collect text input from the player.

- [playdate.timer.keyRepeatTimer()](http://sdk.play.date#f-timer.keyRepeatTimer): Useful, keyboard-style repeating.


### [Link to this](http://sdk.play.date/inside-playdate/\#_buttons "Link to this") 8.4. Buttons

- [playdate.AButtonHeld()](http://sdk.play.date#c-AButtonHeld), [playdate.BButtonHeld()](http://sdk.play.date#c-BButtonHeld): Called after the A or B buttons are held for one second. Useful for adding a "second function" to a button (display a map, for instance).


### [Link to this](http://sdk.play.date/inside-playdate/\#_responding_to_device_events "Link to this") 8.5. Responding to device events

- [playdate.gameWillTerminate()](http://sdk.play.date#c-gameWillTerminate): Notifies your game it’s about to end its execution.

- [playdate.deviceWillLock()](http://sdk.play.date#c-deviceWillLock), [playdate.deviceDidUnlock()](http://sdk.play.date#c-deviceDidUnlock): Notifies your game the Playdate is about to be locked, or woken up.

- [playdate.gameWillPause()/Resume()](http://sdk.play.date#c-gameWillPause): Notifies your game it’s about to be paused or resumed.


### [Link to this](http://sdk.play.date/inside-playdate/\#_drawing_5 "Link to this") 8.6. Drawing

- [playdate.graphics.setDrawOffset()](http://sdk.play.date#f-graphics.setDrawOffset): Force all drawing calls to render with an offset; ideal for games with scrolling content.

- [playdate.ui.gridview](http://sdk.play.date#C-ui.gridview): Render one- or two-dimensional grids of content.

- [playdate.graphics.nineslice](http://sdk.play.date#C-graphics.nineSlice): Create resizable rectangular assets.


### [Link to this](http://sdk.play.date/inside-playdate/\#_effects "Link to this") 8.7. Effects

- [playdate.graphics.image.vcrPauseFilterImage()](http://sdk.play.date#m-graphics.image.vcrPauseFilterImage) \- add glitchiness to your game’s appearance


### [Link to this](http://sdk.play.date/inside-playdate/\#_accessibility "Link to this") 8.8. Accessibility

- [playdate.getReduceFlashing()](http://sdk.play.date#f-getReduceFlashing): Check this at the beginning of your game. If _true_, your game should avoid visuals that could be problematic for people with sensitivities to flashing lights or patterns.


### [Link to this](http://sdk.play.date/inside-playdate/\#_odds_ends "Link to this") 8.12. Odds & ends

- [playdate.graphics.perlin](http://sdk.play.date#f-graphics.perlin): Generate natural-looking patterns.

- [playdate.graphics.generateQRCode](http://sdk.play.date#f-graphics.generateQRCode): Display a QR code onscreen.

- [playdate.serialMessageReceived](http://sdk.play.date#c-serialMessageReceived): Communicate over the USB port.


## 9\. Getting Help

### [Link to this](http://sdk.play.date/inside-playdate/\#_where_do_i_go_if_i_have_questions_about_the_sdk "Link to this") 9.2. Where do I go if I have questions about the SDK?

Searching in the [Get Help](https://devforum.play.date/c/get-help/38) and [Development Discussion](https://devforum.play.date/c/development-discussion/80) on our Developer Forum to find solutions will also be a good place to look at. If you still need help, the best way to get help from either the community or Panic is to post in that same Get Help category.

### [Link to this](http://sdk.play.date/inside-playdate/\#_where_do_i_report_bugs_or_issues_relating_to_the_sdk "Link to this") 9.3. Where do I report bugs or issues relating to the SDK?

Head to the [Bug Reports](https://devforum.play.date/c/bugs/47) category and check the [Bug Report category info](https://devforum.play.date/t/about-the-bug-reports-category/1463) for information on how to post a bug report. One of us at Panic will take a look at it!
And what if I have feature requests?

To share your ideas, suggestions, and requests relating to Playdate, head to the [Feature Request](https://devforum.play.date/c/feature-requests/48) category and check the [Feature Request category info](https://devforum.play.date/t/about-the-feature-requests-category/1464) before posting your feature request.

### [Link to this](http://sdk.play.date/inside-playdate/\#_list_of_helpful_libraries_and_code "Link to this") 9.4. List of Helpful Libraries and Code

This thread includes some helpful tips from the community. Check it out [here](https://devforum.play.date/t/a-list-of-helpful-libraries-and-code/221). For more resources, head to the [Development Discussion](https://devforum.play.date/c/development-discussion/80) category.

## 10\. Legal information

Playdate fonts are licensed to you under the [Creative Commons Attribution 4.0 International (CC BY 4.0) license.](https://creativecommons.org/licenses/by/4.0/)