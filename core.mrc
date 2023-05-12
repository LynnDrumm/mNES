;; mIRC NES emulator

alias nes.init {

        echo -s -------------------------------------
        echo -s mNES v0.2
        echo -s (c) Lynn Drumm 2023
        echo -s All rights and/or wrongs reserved.
        echo -s -------------------------------------

        ;; load opcode script (:

        .load -rs $scriptdir $+ ops.mrc

        ;; create hash table for global storage

        if ($hget(nes.data) != $null) {

                hfree nes.data
        }

        hmake nes.data 10

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

        echo -s reading header bytes:

        ;; first 4 bytes should spell NES in ASCII, + DOS "end-of-file" ($4E, $45, $53, $1A)
        ;; also, remember, mIRC does 1-indexing. so we gotta offset *everything*
        ;; we'll also get decimal values rather than hex. probably not worth converting these,
        ;; since it's just a quick check, though I may as well write a function for this.
        var %headerValue $nes.baseConvertRange($bvar(&header, 1, 4))
        var %headerConst 4E 45 53 1A

        echo -s %headerValue
        echo -s %headerConst

        if (%headerValue == %headerConst) {

                echo -s first 4 bytes match! ^-^
                ;echo -s $qt($nopath(%nes.ROM)) is probably a NES ROM file!

                ;; load ROM as binvar, skipping the first 16 bytes of the header.
                var %ROMsize $calc($file(%nes.ROM).size - 16)
                echo -s ROM size: $bytes(%ROMsize,k).suf $+ , %ROMsize bytes
                bread $qt(%nes.ROM) 16 %ROMsize &ROM

                ;; add the ROM (with header stripped) to the data table.
                ;; this is especially important because binary variables are
                ;; nuked when a script ends.
                hadd -b nes.data rom.data &ROM

                ;; 4th byte (or 5th if starting from 1) contains ROM size in 16k chunks
                var %PRGROMsize $bvar(&header, 5, 1)
                echo -s PRG ROM size: %PRGROMsize * 16k chunks = $calc(%PRGROMsize * 16) $+ k, $calc((%PRGROMsize * 16) * 1024) bytes.

                ;; 5th (6th) byte, CHR ROM size in 8k chunks. 0 means the board uses CHR RAM instead
                var %CHRROMsize $bvar(&header, 6, 1)

                if (%CHRROMsize > 0) {

                        echo -s CHR ROM size: %CHRROMsize * 8k chunks = $calc(%CHRROMsize * 8) $+ k, $calc((%PRGROMsize * 8) * 1024) bytes.
                }

                else {

                        ;; what's CHR RAM? I don't know (yet).
                        echo -s board uses CHR RAM (not ROM)
                }

                ;; ------------------------------------------------------------------
                ;; 6th (7th) byte: oh boy, time to decode individual bits 💀
                ;; ------------------------------------------------------------------

                ;; on 6502, you count bits from right to left. i don't know why.
                var %flags6 $base($bvar(&header, 7, 1), 10, 2, 8)
                ;echo -s byte 06: %flags6

                ;; bit 0: mirroring -- 0 = horizontal mirroring, 1 vertical mirroring.
                var %mirroring $mid(%flags6, 1, 8)
                echo -s mirroring:11 $iif(%mirroring == 1, vertical, horizontal)

                ;; bit 1: does the cartridge have a battery?
                var %battery $mid(%flags6, 1, 7)
                echo -s battery: $iif(%battery == 1, 09true, 04false)

                ;; bit 2: trainer present? what is a "trainer" in this context?

                ;; apparently this is only relevant for modified ROM dumps, something
                ;; which is not really relevant in the current year of our lord 2023,
                ;; unless we're writing a super compatible emulator (we're not).
                var %trainer $mid(%flags6, 1, 6)
                echo -s trainer: $iif(%trainer == 1, 09true, 04false)

                ;; bit 3: ignore mirroring control or previous mirroring bit, and
                ;; set 4 screen VRAM (what is this?)
                var %ignoreMirror $mid(%flags6, 1, 5)
                echo -s ignore mirroring: $iif(%ignoreMirror == 1, 09true, 04false)

                ;; the next 4 bits are the lower nybble of the mapper number (why????)
                ;; just store 'em and combine them with the upper nybble later, i guess
                var %mapperLowerNybble $left(%flags6, 4)
                echo -s mapper lower nybble:11 %mapperLowerNybble

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
                echo -s mapper upper nybble:11 %mapperUpperNybble

                ;; combine the upper and lower nybbles.
                ;; is upper the first 4 digits, or last?
                var %mapperValue $+(%mapperUpperNybble,%mapperLowerNybble)

                echo -s mapper value: Bin: %mapperValue Hex: $base(%mapperValue, 2, 16, 2) Dec: $base(%mapperValue, 2, 10, 2)

                ;; mappers contain all sorts of weird and wonderful hardware
                ;; they also define which address ROM is mapped to, etc
                ;; i don't wanna think about that too much yet though...

                ;; set up RAM. just fill it with zeroes.
                echo -s setting up RAM

                bset &RAM $calc(64 * 1024) 0

                if (%mapperValue == 0) {

                        ;; mapper 000 maps ROM starting at $8000,
                        ;; but is mirrored directly after it, at $C000.
                        hadd nes.data rom.start  8000
                        hadd nes.data rom.mirror C000

                        ;; copy the full ROM into both areas of RAM.
                        bcopy &RAM $dec(8000) &ROM 1 $calc(((%PRGROMsize * 16) * 1024))
                        bcopy &RAM $dec(C000) &ROM 1 $calc(((%PRGROMsize * 16) * 1024))
                }

                ;; find the area of address space the PRG ROM occupies.

                var %ROMstart $hget(nes.data, rom.start)

                echo -s PRG ROM is mapped to %ROMstart - $hex($calc($dec(%ROMstart) + ((%PRGROMsize * 16) * 1024) - 1))


                echo -s -------------------------------------

                ;; create table for 6502 registers and state, and set initial values
                if ($hget(nes.cpu) != $null) {

                        hfree nes.cpu
                }

                hmake nes.cpu 10

                ;; save RAM
                hadd -b nes.cpu RAM &RAM

                ;; address space is 64k, or $FFFF.
                ;; our ROM maps to $8000, and is 16k (PRG) + 8k (CHR)

                ;; big revelation: the NES has _two_ address busses connected to the catridge,
                ;; one for CPU (which is PRG), and one for PPU (which is CHR)

                ;; the program counter should be initialised by
                ;; reading whatever address is stored at $FFFC and then
                ;; jump there and start execution.

                var %startAddressLo $hex($bvar(&RAM, $dec(FFFC)))
                var %startAddressHi $hex($bvar(&RAM, $dec(FFFD)))

                hadd nes.cpu programCounter $dec($+(%startAddressHi,%startAddressLo))

                ;; stack is 256 bytes from $0100 - $01FF.
                ;; it starts at $01FF and is filled from there, backwards.
                hadd nes.cpu stackPointer   $dec(01FF)

                ;; 8 bits indicating the status of the CPU. maybe we should
                ;; split this up into separate values instead of emulating
                ;; a byte. i don't know what's most practical yet.

                ;; the flags are: Negative, Overflow, n/a, n/a, Decimal,
                ;; Interrupt Disable, Zero, and Carry

                ;;                   NVssDIZC
                ;hadd nes.cpu status 00000100

                hadd nes.cpu status.negative    0
                hadd nes.cpu status.overflow    0
                hadd nes.cpu status.decimal     0
                hadd nes.cpu status.interrupt   1
                hadd nes.cpu status.zero        0
                hadd nes.cpu status.carry       0

                ;; set the accumulator and general purpose x/y registers
                ;; to zero, it doesn't matter.
                hadd nes.cpu accumulator 0
                hadd nes.cpu x           0
                hadd nes.cpu y           0

                ;; start main cpu loop
                .timernes.cpu.loop -mh 0 0 nes.cpu.loop
        }

        else {

                echo -s first 4 bytes do not match! x.x
                echo -s $qt($nopath(%nes.ROM)) is probably not a NES ROM file?
        }
}

alias nes.system {

}

alias nes.cpu.loop {

        ;; profiling start
        ;var %ticks $ticks

        ;; make RAM available as binvar
        noop $hget(nes.cpu, ram, &RAM)

        ;; get opcode byte (in hex) at program counter's address
        var %opcode $hex($bvar(&RAM, $hget(nes.cpu, programCounter)))

        ;; return value is typically length, mnemonic, operand
        tokenize 32 $nes.cpu.opcode. [ $+ [ %opcode ] ]

        ;; show pretty output
        nes.cpu.debug %opcode $1-

        var %length $1

        if (%length > 0) {

                ;; increase program counter by instruction length.
                ;; is this the smart way to do it? should instructions do it themselves?
                hinc nes.cpu programCounter %length
        }

        else {


                nes.cpu.stop
        }

        ;; profiling end
        ;echo -s cpu loop took $calc($ticks - %ticks) $+ ms.
}

;; fancy printing of what da cpu doin'
alias nes.cpu.debug {

        ;; all of this is very stupid and hacky and i might get rid of it.
        var %opcode   $1
        var %length   $2
        var %mnemonic $3
        var %mode     $4
        var %operand  $5


        var %pc $+(42$54,$hex($hget(nes.cpu, programCounter)),:)

        if (%mode == immediate) {

                var %operand $+(50#$,62,$base(%operand, 10, 16, 2))
        }

        elseif (%mode == absolute) {

                var %operand $+(50$,62,$base(%operand, 10, 16, 4))
        }

        elseif (%mode == zeropage) {

                var %operand $+(50$,62,$base(%operand, 10, 16, 2))
        }

        echo -s %pc $+(46$58,%opcode,) -> $+(61,%mnemonic) %operand
}

alias nes.cpu.stop {

        if ($timer(nes.cpu.loop) != $null) {

                .timernes.cpu.loop off

                echo -s cpu loop stopped.
        }

        else {

                echo -s cpu is not running.
        }
}

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


alias -l dec {

        return $base($1, 16, 10)
}

alias -l hex {

        return $base($1, 10, 16)
}