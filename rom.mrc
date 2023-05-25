
alias nes.rom.load {

        ;; temporary hardcoded ROM path.
        var %ROMdir $scriptdir $+ ROMs
        ;; just grabs the first .nes file from the path defined above.
        var %nes.ROM $qt($findfile(%ROMdir, *.nes, 1))

        ;; add it to the data table
        hadd nes.data rom.file %nes.ROM

        ;; load header as binvar
        bread $qt(%nes.ROM) 0 16 &header

        ;; parse header
        ;; a lot of this is purely for my own understanding and debugging.

        ;; i should probably move this into it's own function

        echo @nes.debug reading header bytes:

        ;; first 4 bytes should spell NES in ASCII, + DOS "end-of-file" ($4E, $45, $53, $1A)
        ;; also, remember, mIRC does 1-indexing. so we gotta offset *everything*
        ;; we'll also get decimal values rather than hex. probably not worth converting these,
        ;; since it's just a quick check, though I may as well write a function for this.
        var %headerValue $nes.baseConvertRange($bvar(&header, 1, 4))
        var %headerConst 4E 45 53 1A

        echo @nes.debug %headerValue
        echo @nes.debug %headerConst

        if (%headerValue == %headerConst) {

                echo @nes.debug first 4 bytes match! ^-^
                echo @nes.debug $qt($nopath(%nes.ROM)) is probably a NES ROM file!

                ;; load ROM as binvar, skipping the first 16 bytes of the header.
                var %ROMsize $calc($file(%nes.ROM).size - 16)
                echo @nes.debug ROM size: $bytes(%ROMsize,k).suf $+ , %ROMsize bytes
                bread $qt(%nes.ROM) 16 %ROMsize &ROM

                ;; add the ROM (with header stripped) to the data table.
                ;; this is especially important because binary variables are
                ;; nuked when a script ends.
                hadd -b nes.data rom.data &ROM

                ;; 4th byte (or 5th if starting from 1) contains ROM size in 16k chunks
                var %PRGROMsize $bvar(&header, 5, 1)
                echo @nes.debug PRG ROM size: %PRGROMsize * 16k chunks = $calc(%PRGROMsize * 16) $+ k, $calc((%PRGROMsize * 16) * 1024) bytes.

                ;; 5th (6th) byte, CHR ROM size in 8k chunks. 0 means the board uses CHR RAM instead
                var %CHRROMsize $bvar(&header, 6, 1)

                if (%CHRROMsize > 0) {

                        echo @nes.debug CHR ROM size: %CHRROMsize * 8k chunks = $calc(%CHRROMsize * 8) $+ k, $calc((%PRGROMsize * 8) * 1024) bytes.
                }

                else {

                        ;; what's CHR RAM? I don't know (yet).
                        echo @nes.debug board uses CHR RAM (not ROM)
                }

                ;; ------------------------------------------------------------------
                ;; 6th (7th) byte: oh boy, time to decode individual bits 💀
                ;; ------------------------------------------------------------------

                ;; on 6502, you count bits from right to left. i don't know why.
                var %flags6 $base($bvar(&header, 7, 1), 10, 2, 8)
                ;echo @nes.debug byte 06: %flags6

                ;; bit 0: mirroring -- 0 = horizontal mirroring, 1 vertical mirroring.
                var %mirroring $mid(%flags6, 1, 8)
                echo @nes.debug mirroring:11 $iif(%mirroring == 1, vertical, horizontal)

                ;; bit 1: does the cartridge have a battery?
                var %battery $mid(%flags6, 1, 7)
                echo @nes.debug battery: $iif(%battery == 1, 09true, 04false)

                ;; bit 2: trainer present? what is a "trainer" in this context?

                ;; apparently this is only relevant for modified ROM dumps, something
                ;; which is not really relevant in the current year of our lord 2023,
                ;; unless we're writing a super compatible emulator (we're not).
                var %trainer $mid(%flags6, 1, 6)
                echo @nes.debug trainer: $iif(%trainer == 1, 09true, 04false)

                ;; bit 3: ignore mirroring control or previous mirroring bit, and
                ;; set 4 screen VRAM (what is this?)
                var %ignoreMirror $mid(%flags6, 1, 5)
                echo @nes.debug ignore mirroring: $iif(%ignoreMirror == 1, 09true, 04false)

                ;; the next 4 bits are the lower nybble of the mapper number (why????)
                ;; just store 'em and combine them with the upper nybble later, i guess
                var %mapperLowerNybble $left(%flags6, 4)
                echo @nes.debug mapper lower nybble:11 %mapperLowerNybble

                ;; ------------------------------------------------------------------
                ;; 7th (8th) byte:
                ;; ------------------------------------------------------------------
                var %flags7 $base($bvar(&header, 8, 1), 10, 2, 8)

                ;; we're going to ignore the first 2 bits here, since they're mainly
                ;; relevant for arcade(?) hardware like the VS system and Playchoice-10

                ;; bit 2-3 (3-4): if this is = 2, then flags 8 - 15 are NES 2.0 format.
                ;; probably. there's some more detection nuances, we're not gonna worry
                ;; about this for the time being.

                ;; the last 4 bits are the upper nybble of the mapper. lol.
                var %mapperUpperNybble $left(%flags7, 4)
                echo @nes.debug mapper upper nybble:11 %mapperUpperNybble

                ;; combine the upper and lower nybbles.
                ;; is upper the first 4 digits, or last?
                var %mapperValue $+(%mapperUpperNybble,%mapperLowerNybble)

                echo @nes.debug mapper value: Bin: %mapperValue Hex: $base(%mapperValue, 2, 16, 2) Dec: $base(%mapperValue, 2, 10, 2)

                ;; mappers contain all sorts of weird and wonderful hardware
                ;; they also define which address ROM is mapped to, etc
                ;; i don't wanna think about that too much yet though...

                if (%mapperValue == 0) {

                        ;; mapper 000 maps ROM starting at $8000,
                        ;; but is mirrored directly after it, at $C000.
                        hadd nes.data rom.start  8000
                        hadd nes.data rom.mirror C000

                        ;; copy the full ROM into both areas of RAM.
                        bcopy &RAM $base(8000, 16, 10) &ROM 1 $calc(((%PRGROMsize * 16) * 1024))
                        bcopy &RAM $base(C000, 16, 10) &ROM 1 $calc(((%PRGROMsize * 16) * 1024))
                }

                ;; find the area of address space the PRG ROM occupies.

                var %ROMstart $hget(nes.data, rom.start)

                echo @nes.debug PRG ROM is mapped to %ROMstart
                echo @nes.debug -------------------------------------
        }

        else {

                echo @nes.debug first 4 bytes do not match! x.x
                echo @nes.debug $qt($nopath(%nes.ROM)) is probably not a NES ROM file?
        }


}

;; this entire function might be a bit overkill since it's only used once, I think.
alias nes.baseConvertRange {

        ;; i tried using the $* hack here, but it didn't work. sad 😞

        ;; ok, maybe something was going wrong. it seems like whatever $bvar()
        ;; gives us is not delimited with ascii character 32, which is the
        ;; assumed default when handling tokens. weird. very weird.
        ;; i'd rather not have to re-tokenise the string but I also can't seem
        ;; to figure out what the hell the value is for some reason.

        ;; if i look it up online (by copy/pasting from the output), it
        ;; comes back up as ascii code 32. so it should work. but it doesn't
        ;; what the fuck?

        ;; maybe it's just $0 that is broken.
        ;; it should do the same as $numtok($1-, 32), but doesn't. weird. 🙄

        ;; anyway, this converts a range of numbers from decimal to hexadecimal.

        var %i 1
        var %t $numtok($1-, 32)

        while (%i <= %t) {

                var %r $instok(%r, $base($gettok($1-, %i, 32), 10, 16), $calc($numtok(%r, 32) + 1), 32)
                inc %i
        }

        return %r
}