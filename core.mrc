;; mIRC NES emulator

;; da main loop!
alias nes.cpu.loop {

        ;; make RAM available as binvar
        noop $hget(nes.mem, ram, &RAM)

        ;; loop "forever". we'll break out at regular intervals
        ;; and call this again with a timer, but hopefully this
        ;; should be a little bit faster than a pure timer loop?
        while ($true) {

                ;; instruction profiling start
                hadd nes.cpu ticks.instruction $ticksqpc

                ;; increment the current program counter
                hinc nes.cpu programCounter

                ;; get opcode byte (in hex) at program counter's address
                var %opcode $hex($bvar(&RAM, $hget(nes.cpu, programCounter)))

                ;; get mnemonic, instruction length (bytes), and mode
                tokenize 32 $hget(nes.cpu.opcode, %opcode)

                var %mnemonic   $1
                var %length     $2
                var %mode       $3

                ;; set %operand to the next 1-2 bytes. will be ignored if mode is implicit.
                var %operand $bvar(&RAM, $calc($hget(nes.cpu, programCounter) + 1), $calc(%length - 1))

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
                nes.cpu.mnemonic. $+ [ %mnemonic ] %length %mode %operand

                ;; show pretty output
                ;; if we gott a return value, it's in $result
                nes.cpu.debug $hget(nes.cpu, programCounter) %opcode %length %mode %mnemonic %operand $result %ticks

                ;; just count single cycles for now
                hinc nes.cpu cycles

                if ($hget(nes.cpu, cyclesPerTimer) // $hget(nes.cpu, cycles)) {

                        break
                }
        }

        ;; lmfao i didn't notice for DAYS that I was never actually writing &RAM out,
        ;; so i was just loading in a fresh copy of it as set during init on
        ;; every
        ;; single
        ;; cycle.
        ;; ...anyway. fixed now >.>;
        hadd -b nes.mem RAM &RAM

        ;; end of cpu loop
        return

        ;; if something goes wrong, halt the cpu emulation
        :error
        nes.cpu.stop
}

;; resumes CPU from last stop point. $1 is optional timer interval
alias nes.cpu.start {

        var %cycleDelay $1

        iline @nes.debug $line(@nes.debug, -1) resuming cpu

        .timernes.cpu.loop -h 0 $iif(%cycleDelay, %cycleDelay, 0) nes.cpu.loop

        hadd nes.cpu cyclesPerTimer $iif(%cycleDelay, 1, 100)

        ;; start instructions-per-second timer
        hadd nes.cpu ips.last 0
        .timernes.ips.loop 0 1 nes.ips.calc
}

alias nes.cpu.stop {

        if ($timer(nes.cpu.loop) != $null) {

                .timernes.cpu.loop off
                .timernes.ips.loop off

                iline @nes.debug $line(@nes.debug, -1) cpu loop stopped.
                halt
        }

        else {

                iline @nes.debug $line(@nes.debug, -1) cpu is not running.
        }
}

alias nes.ips.calc {

        var %last $hget(nes.cpu, ips.last)
        var %current $hget(nes.cpu, cycles)

        echo -s ips: $calc(%current - %last)

        hadd nes.cpu ips $calc(%current - %last)
        hadd nes.cpu ips.last %current
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

alias nes.cpu.loadOpcodeTable {

        if ($hget(nes.cpu.opcode) != $null) {

                hfree nes.cpu.opcode
        }

        hmake nes.cpu.opcode 256

        ;; file containing list of all ops
        var %file $scriptdir $+ ops.ini
        hload -i nes.cpu.opcode $qt(%file) opcodes

        echo @nes.debug >> opcode table loaded.
}

alias nes.init {

        echo @nes.debug -------------------------------------
        echo @nes.debug mNES v0.4
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
        var %scripts ops ppu mem rom

        while (%i <= $numtok(%scripts, 32)) {

                var %file $gettok(%scripts, %i, 32) $+ .mrc
                echo @nes.debug loading %file
                .load -rs $scriptdir $+ %file
                inc %i
        }

        ;; generate the opcode table
        nes.cpu.loadOpcodeTable

        ;; initialise memory
        nes.mem.init

        ;; load rom and parse header
        nes.rom.load

        ;; initialise the PPU
        nes.ppu.init

        ;; save RAM
        hadd -b nes.mem RAM &RAM

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

        ;; "high resolution" profiling
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
        nes.cpu.start
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
                                var %result $+(50$,74,$base($7, 10, 16, 4),50,$chr(44),74,$hex($hget(nes.cpu, y)))
                        }

                        ;; calculate n prettify execution time
                        var %ticks $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.instruction)),94ms) 91/ $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.start)),94ms91,$chr(44),96) $hget(nes.cpu, ips) 94ips

                        ;; prettify the status flag display
                        var %flags $replace($nes.cpu.statusFlags, 0, $+(30,0), 1, $+(66,1))

                        var %regs 85 $padString(2, $hex($hget(nes.cpu, accumulator))) $padString(2, $hex($hget(nes.cpu, x))) $padString(2, $hex($hget(nes.cpu, y)))

                        ;; the big line that put da stuff on screen~
                        ;; this is getting a bit unwieldy, lol
                        iline @nes.debug $line(@nes.debug, -1) %cycles %pc 93: %opcode $padString(5, %operand) 93-> $+(71,%mnemonic) $padString(8, %result) $padString(10, %regs) $padString(11, $+(94,%mode)) $padString(10, %flags) %ticks
                        ;echo @nes.debug %cycles %pc 93: %opcode $padString(5, %operand) 93-> $+(71,%mnemonic) $padString(6, %result) $padString(10, %regs) $padString(11, $+(94,%mode)) $padString(10, %flags) %ticks
                }
        }

        else {

                ;; print a warning if we encounter an unimplemented opcode
                echo @nes.debug %cycles %pc 93: %opcode $padString(5, %operand) 93-> 54,52 $+ /!\66,28 $+ $+($chr(160),unimplemented instruction,$chr(160),) $+(96,$calc($ticksqpc - $hget(nes.cpu, ticks.start)),94ms)
        }
}

alias -l debugHeader {

        echo @nes.debug 91---95cyl91-95pc91------95op91-95oprnd91----95mnm91-95result91----95A91--95X91--95Y91----95mode91--------95NVssDIZC91---95exec91--95real91------------
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