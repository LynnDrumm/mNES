;; mIRC NES emulator

alias nes.init {

        echo -s -------------------------------------
        echo -s mNES v0.3
        echo -s (c) Lynn Drumm 2023
        echo -s All rights and/or wrongs reserved.
        echo -s -------------------------------------

        ;; load and init opcode script (:

        .load -rs $scriptdir $+ ops.mrc
        nes.cpu.generateOpcodeTable

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

                ;; we decrease it by 1 so it's in the correct position when the cpu loop starts
                hadd nes.cpu programCounter $calc($dec($+(%startAddressHi,%startAddressLo)) - 1)

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
        set %ticks $ticks

        ;; make RAM available as binvar
        noop $hget(nes.cpu, ram, &RAM)

        ;; increment the current program counter, and assign it to %pc
        hinc nes.cpu programCounter

        ;; get opcode byte (in hex) at program counter's address
        var %opcode $hex($bvar(&RAM, $hget(nes.cpu, programCounter)))

        ;; get mnemonic, instruction length (bytes), and mode
        tokenize 32 $hget(nes.cpu.opcode, %opcode)

        var %mnemonic   $1

        if (%mnemonic != $null) {

                var %length     $2
                var %mode       $3

                ;; increment the program counter by operand length.
                ;; this must be done BEFORE executing the instruction.
                hinc nes.cpu programCounter %length

                ;; set %operand if instruction length >1 bytes, else leave it empty.
                var %operand $iif(%length > 1, $bvar(&RAM, $calc($hget(nes.cpu, programCounter) - 2), $calc(%length - 1)))

                ;; execute it
                nes.cpu.mnemonic. [ $+ [ %mnemonic ] ] %length %mode %operand

                ;; if we get a return value, put it in %result, else keep it empty.
                var %result $result

                ;; show pretty output
                nes.cpu.debug $hget(nes.cpu, programCounter) %opcode %length %mode %mnemonic %operand %result %ticks
        }

        else {

                ;; just pretend the instruction length is 0
                nes.cpu.debug $hget(nes.cpu, programCounter) %opcode 0
                nes.cpu.stop
        }

        ;; if something goes wrong, halt the cpu emulation

        return
        :error
        nes.cpu.stop
}

;; i may have to re-do the whole debug display after all
;; it doesn't really work for showing both the instruction
;; *and* the result (like with BEQ, for example).

;; so. let's re-think this, then?
alias nes.cpu.debug {

        var %pc         $+(41$,65,$hex($1))
        var %opcode     $+(4468,$2)
        var %length     $3

        ;; instructions are at least 1 byte long.
        ;; if not, well, it's just not implemented yet!
        if (%length > 0) {

                var %mode       $4
                var %mnemonic   $+(71,$5)

                ;; special handling for how to display the operand/result depending on length/mode
                if (%mode == implicit) {

                        ;; since implicit instructions have no operand or "result",
                        ;; %ticks is set to the 6th parameter.

                        var %ticks $6

                        var %result %operand
                }

                elseif (%mode == immediate) {

                        var %ticks $7

                        ;; immediate mode means the operand is a single byte direct value,
                        ;; to be prefixed with #$, not to be confused with zeropage, which
                        ;; is also a single byte operand but is displayed as an 8-bit address.
                        var %operand $+(57,$base($6, 10, 16, 2))
                        var %result $+(50#$,74,$base($6, 10, 16, 2))

                }

                elseif (%mode == absolute) {

                        var %ticks $8

                        ;; this is an address
                        var %operand $+(57,$base($6, 10, 16, 2)) $+(69,$base($7, 10, 16, 2))
                        var %result $+(50$,74,$base($+($hex($6),$hex($7)), 16, 16, 4))
                }

                elseif (%mode == relative) {

                        var %ticks $8

                        ;; if mode is relative, we'd rather display the result of the
                        ;; instruction, so we can see where a branch ends up,
                        ;; rather than the offset we may or not be adding/subtracting.

                        ;; we're still keeping the original operand as well though,
                        ;; just to keep things clear
                        var %operand $+(57,$base($6, 10, 16, 2))
                        var %result $+(50$,74,$base($7, 10, 16, 4))
                }

                elseif (%mode == zeropage) {

                        var %ticks $7

                        ;; operands on single page operations are only 1 byte long.
                        var %operand $+(57,$base($6, 10, 16, 2))
                        var %result $+(50$,74,$base($6, 10, 16, 2))
                }

                ;; calculate n prettify execution time
                var %ticks 96 $+ $calc($ticks - %ticks) $+ 94ms.

                ; the big line that put da stuff on screen~
                echo -s %pc 93: %opcode $padString(5, %operand) 93-> %mnemonic $padString(8, %result) $padString(12, $+(94,%mode)) %ticks
        }

        else {

                ;; print a warning if we encounter an unimplemented opcode
                echo -s %pc 93: 54,52 $+ /!\ 66,28 $+ $+($chr(160),%mnemonic,$chr(160))
        }
}

;; pad $2- up to $1 characters, using $chr(160) ((unicode space))
alias -l padString {

        var %stringLength       $len($strip($2-))
        var %newLength          $1
        var %padLength          $calc(%newLength - %stringLength)
        var %padding            $str($chr(160),%padLength)

        return $iif($prop == pre, $+(%padding,$2-), $+($2-,%padding))
}

alias nes.cpu.stop {

        if ($timer(nes.cpu.loop) != $null) {

                .timernes.cpu.loop off

                echo -s cpu loop stopped.
                halt
        }

        else {

                echo -s cpu is not running.
        }
}

alias nes.cpu.generateOpcodeTable {

        if ($hget(nes.cpu.opcode) != $null) {

                hfree nes.cpu.opcode
        }

        hmake nes.cpu.opcode 256

        echo -s >> generating opcode table...

        ;; file containing list of all ops
        var %file $scriptdir $+ ops.dat

        ;; get total entries in file
        var %t $lines(%file)
        var %i 1

        while (%i <= %t) {

                var %entry $read(%file, %i)
                echo -s adding $+(,$rand(76,87),$read(%file, %i))
                hadd nes.cpu.opcode %entry
                inc %i
        }

        echo -s >> opcode table generated.
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

;; explicit hex -> decimal conversion
alias -l dec {

        return $base($1, 16, 10)
}

;; explicit decimal -> hex conversion
alias -l hex {

        return $base($1, 10, 16)
}