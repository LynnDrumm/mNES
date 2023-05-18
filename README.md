# mNES
NES emulator in mIRCscript

![image](https://github.com/LynnDrumm/mNES/assets/80856352/cff090ab-e14c-46e6-a0ed-bccdd5f9d22d)

this is a learning experience for me. Figuring things out as I go. I don't know what I'm doing, please keep that in mind if you read the source.

only a small handful of opcodes are (probably poorly) emulated so far, don't expect much to run (yet), but feel free to look around and give me feedback ^-^


# how to use:

put a folder named ROMs in the same directory as all the files, and put a valid NES rom there.
currently, it just picks the first file it finds in there.

then you can load the script(s) with /load -rs path\to\core.mrc, followed by /nes.init to run it.
