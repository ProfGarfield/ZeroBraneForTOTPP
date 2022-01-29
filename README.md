# ZeroBrane Studio for Test of Time Patch Project

This is a modification of [ZeroBrane Studio](https://github.com/pkulchenko/ZeroBraneStudio)(v1.90), designed to facilitate programming Lua events for Civilization II: Test of Time with [Test of Time Patch Project](https://forums.civfanatics.com/threads/the-test-of-time-patch-project.517282/).

## Installation

If you're using Windows, you can simply click the green 'code' button to download the .zip file.  Extract it to a convenient location, then run zbstudio.exe to launch the program.  This is a portable version, so there is no installation process.  You may wish to create a shortcut to zbstudio.exe.

Alternatively, you can download an [official version of the program](https://studio.zerobrane.com/download?not-this-time), and replace the following files with the ones provided here.

Add the package [cloneview.lua](https://raw.githubusercontent.com/ProfGarfield/ZeroBraneForTOTPP/main/packages/cloneview.lua) to the `packages` folder: `packages\cloneview.lua`

Add the package [totpp.lua](https://raw.githubusercontent.com/ProfGarfield/ZeroBraneForTOTPP/main/packages/totpp.lua) to the `packages` folder: `packages\totpp.lua`

Download [lua.lua]() and replace the file in the `spec` folder: `spec\lua.lua`

Download [autocomplete.lua]() and replace the file in `src\editor` folder: `src\editor\autocomplete.lua`

Add the configuration file [user.lua]() to the `cfg` folder: `cfg\user.lua`
