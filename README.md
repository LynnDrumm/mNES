# mNES
NES emulator in mIRCscript

![image](https://github.com/LynnDrumm/mNES/assets/80856352/cff090ab-e14c-46e6-a0ed-bccdd5f9d22d)

this is a learning experience for me. Figuring things out as I go. I don't know what I'm doing, please keep that in mind if you read the source.

only a small handful of opcodes are (probably poorly) emulated so far, don't expect much to run (yet), but feel free to look around and give me feedback ^-^


# how to use:

put a folder named ROMs in the same directory as all the files, and put a valid NES rom there.
currently, it just picks the first file it finds in there.

then you can load the script(s) with `/load -rs path\to\core.mrc`, followed by `/nes.init` to run it. It will not show (much) output by default.
if you want the pretty CPU output (about the only interesting thing to look at currently), `/nes.init full` will accomplish that, or `/nes.init error` if you (mostly) just want to show errors.

You can also manually turn on the output while the emulator runs by typing `/hadd nes.cpu debug full`, or you can set it to `error` to only show output when an error occurs. You can manipulate the status registers (`nes.cpu status.xxxxx`), accumulator, x, y, program counter, and so on the same way, if you like.

`/nes.init` will always cleanly start the emulator, `/nes.cpu.start [n]` will start the emulator from the last known state, where `n` is the amount of miliseconds to wait between each cpu cycle. `/nes.cpu.stop` will stop the emulator (and is (or should be) automatically triggered when an error occurs).
