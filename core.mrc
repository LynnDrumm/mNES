;; mIRC NES emulator

alias nes.init {

        echo @nes.debug -------------------------------------
        echo @nes.debug mNES v0.3
        echo @nes.debug (c) Lynn Drumm 2023
        echo @nes.debug All rights and/or wrongs reserved.
        echo @nes.debug -------------------------------------

        ;; open our own window
        window -e @nes.debug

        ;; create hash table for global storage

        if ($hget(nes.data) != $null) {

                hfree nes.data
        }

        hmake nes.data 10

        ;; load other scripts

        var %i 1
        var %scripts ops ppu mem

        while (%i <= $numtok(%scripts, 32)) {

                var %file $gettok(%scripts, %i, 32) $+ .mrc

                echo @nes.debug loading %file

                .load -rs $scriptdir $+ %file

                inc %i
        }

        ;; generate the opcode table
        nes.cpu.generateOpcodeTable

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
                ;echo @nes.debug $qt($nopath(%nes.ROM)) is probably a NES ROM file!

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

                ;; initialise memory
                nes.mem.init

                ;; initialise the PPU
                nes.ppu.init

                if (%mapperValue == 0) {

                        ;; mapper 000 maps ROM starting at $8000,
                        ;; but is mirrored directly after it, at $C000.
                        hadd nes.data rom.start  8000
                        hadd nes.data rom.mirror C000

                        ;; copy the full ROM into both areas of RAM.
                        bcopy &RAM $dec(8000) &ROM 1 $calc(((%PRGROMsize * 16) * 1024))
                        bcopy &RAM $dec(C000) &ROM 1 $calc(((%PRGROMsize * 16) * 1024))
                }

                ;; save RAM
                nes.mem.save RAM

                ;; find the area of address space the PRG ROM occupies.

                var %ROMstart $hget(nes.data, rom.start)

                echo @nes.debug PRG ROM is mapped to %ROMstart - $hex($calc($dec(%ROMstart) + ((%PRGROMsize * 16) * 1024) - 1))
                echo @nes.debug -------------------------------------

                ;; create table for 6502 registers and state, and set initial values
                if ($hget(nes.cpu) != $null) {

                        hfree nes.cpu
                }

                hmake nes.cpu 10

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

                ;; 8 bits indicating the status of the CPU. maybe we should
                ;; split this up into separate values instead of emulating
                ;; a byte. i don't know what's most practical yet.

                ;; the flags are: Negative, Overflow, n/a, n/a, Decimal,
                ;; Interrupt Disable, Zero, and Carry

                ;;                   NVsBDIZC
                ;hadd nes.cpu status 00000100

                ;; ok, we forgot about bits 4 and 5.
                ;; these are handled differently, so, maybe separating things
                ;; out like this was not the best idea, and maybe we should
                ;; write a function to handle this stuff instead.

                ;; writing a function to handle it ended up being more of a
                ;; pain than solution, so we'll leave it for now.

                ;; bit 5 has no name. i don't like that but it's how it is.

                hadd nes.cpu status.negative    0
                hadd nes.cpu status.overflow    0
                hadd nes.cpu status.5           0
                hadd nes.cpu status.break       0
                hadd nes.cpu status.decimal     0
                hadd nes.cpu status.interrupt   1
                hadd nes.cpu status.zero        0
                hadd nes.cpu status.carry       0

                ;; set the accumulator and general purpose x/y registers
                ;; to zero, it doesn't matter.
                hadd nes.cpu accumulator 0
                hadd nes.cpu x           0
                hadd nes.cpu y           0

                ;; just counting single cycles for now
                hadd nes.cpu cycles 0

                ;;
                hadd nes.cpu ticks.start $ticksqpc

                ;; debug output selector.
                ;; full shows everything, error only shows errors, none shows... none!
                ;; this is not completely implemented but it's a start
                hadd nes.cpu debug $iif($1, $1, error)

                if ($hget(nes.cpu, debug) == full) {

                        ;; print debug header, twice. this is because our cpu output
                        ;; gets printed right in between, so that it's easier to read
                        ;; the output even if we're all the way at the end.
                        debugHeader
                        debugHeader

                }

                ;; start main cpu loop
                .timernes.cpu.loop -mh 0 0 nes.cpu.loop
        }

        else {

                echo @nes.debug first 4 bytes do not match! x.x
                echo @nes.debug $qt($nopath(%nes.ROM)) is probably not a NES ROM file?
        }
}

;; da main loop!
alias nes.cpu.loop {

        ;; instruction profiling start
        hadd nes.cpu ticks.instruction $ticksqpc

        ;; make RAM available as binvar
        noop $hget(nes.mem, ram, &RAM)

        ;; increment the current program counter
        hinc nes.cpu programCounter

        ;; assign it to %pc, this is only for debug output,
        ;; since it will be manipulated in the meantime.
        var %pc $hget(nes.cpu, programCounter)

        ;; get opcode byte (in hex) at program counter's address
        var %opcode $hex($bvar(&RAM, $hget(nes.cpu, programCounter)))

        ;; get mnemonic, instruction length (bytes), and mode
        tokenize 32 $hget(nes.cpu.opcode, %opcode)

        var %mnemonic   $1

        if (%mnemonic != $null) {

                var %length     $2
                var %mode       $3

                ;; set %operand if instruction length >1 bytes, else leave it empty.
                var %operand $iif(%length > 1, $bvar(&RAM, $calc($hget(nes.cpu, programCounter) + 1), $calc(%length - 1)))

                ;; increment the program counter by operand length.
                ;; this must be done BEFORE executing the instruction.
                hinc nes.cpu programCounter $calc(%length - 1)

                ;; execute the instruction
                ;; currently we're dynamically calling individual instructions
                ;; based on mnemonic name (and using if/then conditioning for
                ;; different modes), because I suspect it might be faster,
                ;; however, if it turns out to be more practical to have one
                ;; big function and put the mnemonics in if/then blocks too,
                ;; we can always switch to that later.
                nes.cpu.mnemonic. [ $+ [ %mnemonic ] ] %length %mode %operand

                ;; if we get a return value, put it in %result, else keep it empty.
                ;; i feel so silly for not knowing there was a way to get return
                ;; values without calling aliases as an $identifier. oh well!
                var %result $result

                ;; show pretty output
                if (1 // $hget(nes.cpu, cycles)) {

                        nes.cpu.debug %pc %opcode %length %mode %mnemonic %operand %result %ticks
                }
        }

        else {

                ;; just pretend the instruction length is 0
                nes.cpu.debug $hget(nes.cpu, programCounter) %opcode 0
                nes.cpu.stop
        }

        ;; just count single cycles for now
        hinc nes.cpu cycles

        ;; lmfao i didn't notice for DAYS that I was never actually writing &RAM out,
        ;; so i was just loading in a fresh copy of it as set during init on
        ;; every
        ;; single
        ;; cycle.
        ;; ...anyway. fixed now >.>;
        nes.mem.save RAM

        ;; if something goes wrong, halt the cpu emulation
        return
        :error
        nes.cpu.stop
}

alias nes.cpu.stop {

        if ($timer(nes.cpu.loop) != $null) {

                .timernes.cpu.loop off

                echo @nes.debug cpu loop stopped.
                halt
        }

        else {

                echo @nes.debug cpu is not running.
        }
}

;; get 6502 status flags as a single byte, represented in binary
alias nes.cpu.statusFlags {

        ;; from most to least significant (byte 7 - 0)
        var %N $hget(nes.cpu, status.negative)
        var %V $hget(nes.cpu, status.overflow)

        ;; bits 5 and 4 are not used and always 0
        ;; -- i was wrong, they absolutely get used,
        ;;    just not when programming FOR the cpu.
        ;;    ...usually anyway. it's complicated.

        var %5 $hget(nes.cpu, status.5)
        var %B $hget(nes.cpu, status.break)

        var %D $hget(nes.cpu, status.decimal)
        var %I $hget(nes.cpu, status.interrupt)
        var %Z $hget(nes.cpu, status.zero)
        var %C $hget(nes.cpu, status.carry)

        ;; merge 'em all together and return the result!
        return $+(%N,%V,%5,%B,%D,%I,%Z,%C)
}

alias nes.cpu.generateOpcodeTable {

        if ($hget(nes.cpu.opcode) != $null) {

                hfree nes.cpu.opcode
        }

        hmake nes.cpu.opcode 256

        echo @nes.debug >> generating opcode table...

        ;; file containing list of all ops
        var %file $scriptdir $+ ops.dat

        ;; get total entries in file
        var %t $lines(%file)
        var %i 1

        while (%i <= %t) {

                var %entry $read(%file, %i)
                echo @nes.debug adding $+(,$rand(76,87),$read(%file, %i))
                hadd nes.cpu.opcode %entry
                inc %i
        }

        echo @nes.debug >> opcode table generated.
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

alias nes.cpu.debug {

        var %cycles     $+(72,$padstring(6, $hget(nes.cpu, cycles)).pre)
        var %pc         $+(41$,65,$base($1, 10, 16, 4))
        var %opcode     $+(4468,$2)
        var %length     $3

        ;; instructions are at least 1 byte long.
        ;; if not, well, it's just not implemented yet!
        if (%length > 0) {

                if ($hget(nes.cpu, debug) == full) {

                        var %mode       $4
                        var %mnemonic   $5

                        ;; special handling for how to display the operand/result depending on length/mode
                        if (%mode == implicit) {

                                ;; since implicit instructions have no operand or "result",
                                var %result %operand
                        }

                        elseif (%mode == immediate) {

                                ;; immediate mode means the operand is a single byte direct value,
                                ;; to be prefixed with #$, not to be confused with zeropage, which
                                ;; is also a single byte operand but is displayed as an 8-bit address.
                                var %operand $+(57,$base($6, 10, 16, 2))
                                var %result $+(50#$,74,$base($6, 10, 16, 2))

                        }

                        elseif (%mode == absolute) {

                                ;; this is an address. for display purposes, swap them bytes again.
                                var %operand $+(57,$base($6, 10, 16, 2)) $+(69,$base($7, 10, 16, 2))
                                var %result $+(50$,74,$+($hex($7),$hex($6)))
                        }

                        elseif (%mode == relative) {

                                ;; if mode is relative, we'd rather display the result of the
                                ;; instruction, so we can see where a branch ends up,
                                ;; rather than the offset we may or not be adding/subtracting.

                                ;; we're still keeping the original operand as well though,
                                ;; just to keep things clear
                                var %operand $+(57,$base($6, 10, 16, 2))
                                var %result $+(50$,74,$base($7, 10, 16, 4))
                        }

                        elseif (%mode == zeropage) {

                                ;; operands on single page operations are only 1 byte long.
                                var %operand $+(57,$base($6, 10, 16, 2))
                                var %result $+(50$,74,$base($6, 10, 16, 2))
                        }

                        elseif (%mode == indirect,y) {

                                ;; this is an address. for display purposes, swap them bytes again.
                                var %operand $+(57,$base($6, 10, 16, 2))
                                var %result $+(50$,74,$base($7, 10, 16, 4))
                        }

                        ;; calculate n prettify execution time
                        var %ticks $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.instruction)),94ms) 92/ $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.start)),94ms)

                        ;; prettify the status flag display
                        var %flags $replace($nes.cpu.statusFlags, 0, $+(30,0), 1, $+(66,1))

                        var %regs 85 $padString(2, $hex($hget(nes.cpu, accumulator))) $padString(2, $hex($hget(nes.cpu, x))) $padString(2, $hex($hget(nes.cpu, y)))

                        ;; the big line that put da stuff on screen~
                        ;; this is getting a bit unwieldy, lol
                        iline @nes.debug $line(@nes.debug, -1) %cycles %pc 93: %opcode $padString(5, %operand) 93-> $+(71,%mnemonic) $padString(6, %result) $padString(10, %regs) $padString(11, $+(94,%mode)) $padString(10, %flags) %ticks
                        ;echo @nes.debug %cycles %pc 93: %opcode $padString(5, %operand) 93-> $+(71,%mnemonic) $padString(6, %result) $padString(10, %regs) $padString(11, $+(94,%mode)) $padString(10, %flags) %ticks
                }
        }

        else {

                ;; print a warning if we encounter an unimplemented opcode
                echo @nes.debug %cycles %pc 93: %opcode $padString(5, %operand) 93-> 54,52 $+ /!\66,28 $+ $+($chr(160),unimplemented instruction,$chr(160),) $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.start)),94ms)
        }
}

alias -l debugHeader {

        echo @nes.debug 91---95cyl91-95pc91------95op91-95oprnd91----95mnm91-95result91--95A91--95X91--95Y91----95mode91--------95NVssDIZC91---95exec91--95real91-----
}

;; pad $2- up to $1 characters, using $chr(160) ((unicode space))
alias -l padString {

        var %stringLength       $len($strip($2-))
        var %newLength          $1
        var %padLength          $calc(%newLength - %stringLength)
        var %padding            $str($chr(160),%padLength)

        return $iif($prop == pre, $+(%padding,$2-), $+($2-,%padding))
}

;; explicit hex -> decimal conversion
alias -l dec {

        return $base($1, 16, 10)
}

;; explicit decimal -> hex conversion
alias -l hex {

        return $base($1, 10, 16, 2)
}