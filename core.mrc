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

                ;; assign it to %pc so it stays persistent for debug output
                var %pc $hget(nes.cpu, programCounter)

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
                nes.debug.cpu %pc %opcode %length %mode %mnemonic %operand $result %ticks

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
        nes.debug.cpu $hget(nes.cpu, programCounter) %opcode 0
        nes.cpu.stop
        halt
}

;; resumes CPU from last stop point. $1 is optional timer interval
alias nes.cpu.start {

        ;; reload opcode table -- just for testing.
        nes.cpu.loadOpcodeTable

        ;; get cycle delay value
        var %cycleDelay $1

        ;; number of cycles to run per timer interval.
        ;; if mIRC locks up too much, adjust this down.
        ;; anything 100 or less is a sane value, above that it gets
        ;; *really* impractical as this also affects keyboard input.
        var %cyclesPerInterval 50

        ;; if cycleDelay is set at all, cycles per interval is always 1.
        hadd nes.cpu cyclesPerTimer $iif(%cycleDelay, 1, %cyclesPerInterval)

        ;; start cpu loop
        iline @nes.debug $line(@nes.debug, 0) resuming cpu
        .timernes.cpu.loop -h 0 $iif(%cycleDelay, %cycleDelay, 0) nes.cpu.loop

        ;; start instructions-per-second timer
        hadd nes.cpu ips.last 0
        .timernes.ips.loop 0 1 nes.ips.calc

        ;; benchmark start
        set %debug.ticks.start $ticks
}

alias nes.cpu.stop {

        .timernes.cpu.loop off
        .timernes.ips.loop off

        iline @nes.debug $line(@nes.debug, 0) cpu loop stopped.

        ;; benchmark output
        echo @nes.debug execution took $calc(($ticks - %debug.ticks.start) / 1000) seconds.
        unset %debug.ticks.start

        halt
}

alias nes.cpu.step {

        nes.cpu.loop
}

alias nes.ips.calc {

        var %last $hget(nes.cpu, ips.last)
        var %current $hget(nes.cpu, cycles)

        ;echo -s ips: $calc(%current - %last)

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

        iline @nes.debug $line(@nes.debug, 0) >> opcode table loaded.
}

alias nes.init {

        ;; open our own window
        ;; add a side listbox to display stack and other info
        window -el16 @nes.debug

        echo @nes.debug -------------------------------------
        echo @nes.debug mNES v0.4
        echo @nes.debug (c) Lynn Drumm 2023 - 2025
        echo @nes.debug All rights and/or wrongs reserved.
        echo @nes.debug -------------------------------------

        ;; create hash table for global storage
        if ($hget(nes.data) != $null) {

                hfree nes.data
        }

        hmake nes.data 10

        ;; load other scripts
        var %i 1
        var %scripts ops ppu mem rom debug

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

        ;; debug init
        nes.debug.init $1

        ;; start main cpu loop
        nes.cpu.start $iif($1 isnum, $1, $2)
}

;; explicit hex -> decimal conversion
alias -l dec {

        return $base($1, 16, 10)
}

;; explicit decimal -> hex conversion
alias -l hex {

        return $base($1, 10, 16, 2)
}