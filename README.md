# ZeroBrane Studio for Test of Time Patch Project

This is a modification of [ZeroBrane Studio](https://github.com/pkulchenko/ZeroBraneStudio)(v1.90), designed to facilitate programming Lua events for Civilization II: Test of Time with [Test of Time Patch Project](https://forums.civfanatics.com/threads/the-test-of-time-patch-project.517282/).

## Installation

If you're using Windows, you can simply click the green 'code' button to download the .zip file.  Extract it to a convenient location, then run zbstudio.exe to launch the program.  This is a portable version, so there is no installation process.  You may wish to create a shortcut to zbstudio.exe.

Alternatively, if you want a proper installer or you're not using Windows, you can download an [official version of the program](https://studio.zerobrane.com/download?not-this-time), and replace the following files with the ones provided here.  (Right click the link and "Save link as..." to download the file instead of opening it.)

Add the package [cloneview.lua](https://raw.githubusercontent.com/ProfGarfield/ZeroBraneForTOTPP/main/packages/cloneview.lua) to the `packages` folder: `packages\cloneview.lua`

Add the package [totpp.lua](https://raw.githubusercontent.com/ProfGarfield/ZeroBraneForTOTPP/main/packages/totpp.lua) to the `packages` folder: `packages\totpp.lua`

Download [lua.lua](https://raw.githubusercontent.com/ProfGarfield/ZeroBraneForTOTPP/main/spec/lua.lua) and replace the file in the `spec` folder: `spec\lua.lua`

Download [autocomplete.lua](https://raw.githubusercontent.com/ProfGarfield/ZeroBraneForTOTPP/main/src/editor/autocomplete.lua) and replace the file in `src\editor` folder: `src\editor\autocomplete.lua`

Add the configuration file [user.lua](https://raw.githubusercontent.com/ProfGarfield/ZeroBraneForTOTPP/main/cfg/user.lua) to the `cfg` folder: `cfg\user.lua`

## Special Features

This fork of ZeroBrane Studio automatically provides syntax highlighting along with tooltips and autocomplete for the functions, methods, and properties of the Test of Time Patch Project implementation of Lua.  In addition to adding the relevant ZeroBrane API for the TOTPP features, the ZeroBrane code has been modified to give tooltips for property calls to TOTPP Lua Objects, and to guess what the base object is by using autocomplete calls.

In addition, whenever you open a project folder, ZeroBrane Studio will look for a file totpp-api.lua in the Scripts folder, and, if it is available, use it to update the syntax highlighting, tooltips, and autocomplete.  If you use my [Lua Scenario Template](https://github.com/ProfGarfield/LuaTemplate), you can run the script makeZeroBraneAPI.lua from the Civ II Lua Console.  This will add all your entries in object.lua to the autocomplete list, as well as add tooltips and syntax highlighting to any documentation I add to the files in the LuaCore.

## License

Here is the original license.

[LICENSE](LICENSE).

The changes I've made are all released under the MIT License.


## Changes to the original version of ZeroBrane Studio

Added package cloneview.lua to packages\cloneview.lua.

Created package totpp.lua in packages\totpp.lua.  This package mostly adds the feature of looking for an API in the project folder.

Changed the lua.lua spec in spec\lua.lua.  The returned table is now first assigned to the global variable luaSpec, so that the totpp.lua package can add extra keywords.

Changed autocomplete.lua in src\editor\autocomplete.lua.  Tooltips now available for "class" and "lib" types in the api.  (Can get tooltip for library prefixes, and for class names.)  Tooltip now shows method with ":" separator instead of ".".  Tooltips now display for class properties/values, at least when the autocomplete would also be able to provide the class.

Added user.lua to cfg\user.lua to add the "totpp" api by default.
